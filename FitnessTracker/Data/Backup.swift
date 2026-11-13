import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - DTOs (versioned file format)

/// On-disk backup format. Bump `currentVersion` when the shape changes and keep
/// decoding older versions.
struct BackupFile: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var programs: [ProgramDTO]
    var workouts: [WorkoutDTO]
}

struct ProgramDTO: Codable, Equatable {
    /// Stable ID: normalized title (programs are unique by title, case-insensitive).
    var id: String
    var title: String
    var type: String
}

struct WorkoutDTO: Codable, Equatable {
    /// Stable ID: same key DataDeduper uses (normalized title + start minute).
    var id: String
    var programID: String?
    var date: Date
    var durationMinutes: Double
    var distanceMiles: Double
    var calories: Int
    var elevationFeet: Int
    var avgRPM: Int
    var avgWatts: Int
    var inclineAvg: Double
    var inclineMax: Double
    var resistanceAvg: Int
    var resistanceMax: Int
    var notes: String?
    /// Base64 JPEG in JSON (Data's default Codable representation).
    var photoData: Data?
    var isSimulated: Bool
    /// Thumbnail framing for `photoData`. Optional so backups made before #51 still decode; rides
    /// restored without it are analyzed by `ThumbnailFocusBackfill`.
    var thumbnailFocus: ThumbnailFocusDTO?
    var thumbnailFocusAnalysisVersion: Int?
}

/// Normalized region of the photo (fractions, top-left origin).
struct ThumbnailFocusDTO: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = Double(rect.minX)
        y = Double(rect.minY)
        width = Double(rect.width)
        height = Double(rect.height)
    }

    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}

enum BackupError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "This backup was made by a newer version of FitnessTracker (format \(version)). Update the app to import it."
        case .unreadable(let why):
            "The file isn't a FitnessTracker backup (\(why))."
        }
    }
}

struct ImportSummary: Equatable {
    var workoutsAdded = 0
    var workoutsSkipped = 0
    var programsAdded = 0
    var replaced = false

    var message: String {
        var parts = [inflected("^[\(workoutsAdded) ride](inflect: true) added")]
        if workoutsSkipped > 0 {
            parts.append(inflected("^[\(workoutsSkipped) duplicate](inflect: true) skipped"))
        }
        if programsAdded > 0 {
            parts.append(inflected("^[\(programsAdded) new program](inflect: true)"))
        }
        return (replaced ? "Replaced all data. " : "") + parts.joined(separator: ", ") + "."
    }
}

enum ImportMode: String, CaseIterable, Identifiable {
    case merge = "Merge"
    case replace = "Replace All"

    var id: String { rawValue }
}

// MARK: - Service

enum BackupService {
    /// Shared because the custom encode/decode strategies run once per date in a backup.
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Default options (`.withInternetDateTime`), used as a fallback when reading dates without a fraction.
    private static let iso8601 = ISO8601DateFormatter()

    static func programID(_ title: String) -> String {
        Program.normalizedTitleKey(title)
    }

    static func makeBackup(_ context: ModelContext, includeSimulated: Bool = false, now: Date = .now) -> BackupFile {
        let workouts = ((try? context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)]))) ?? [])
            .filter { includeSimulated || !$0.isSimulated }
        let programs = ((try? context.fetch(FetchDescriptor<Program>(sortBy: [SortDescriptor(\.title)]))) ?? [])
            .filter { program in includeSimulated || (program.workouts ?? []).contains { !$0.isSimulated } || (program.workouts ?? []).isEmpty }
        return BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: now,
            programs: programs.map { ProgramDTO(id: programID($0.title), title: $0.title, type: $0.typeRaw) },
            workouts: workouts.map { workout in
                WorkoutDTO(id: DataDeduper.key(workout), programID: workout.program.map { programID($0.title) },
                           date: workout.date, durationMinutes: workout.durationMinutes, distanceMiles: workout.distanceMiles,
                           calories: workout.calories, elevationFeet: workout.elevationFeet, avgRPM: workout.avgRPM,
                           avgWatts: workout.avgWatts, inclineAvg: workout.inclineAvg, inclineMax: workout.inclineMax,
                           resistanceAvg: workout.resistanceAvg, resistanceMax: workout.resistanceMax,
                           notes: workout.notes, photoData: workout.photoData, isSimulated: workout.isSimulated,
                           thumbnailFocus: workout.thumbnailFocus.map { ThumbnailFocusDTO($0) },
                           thumbnailFocusAnalysisVersion: workout.photoData == nil ? nil : workout.thumbnailFocusAnalysisVersion)
            })
    }

    // ISO 8601 with fractional seconds on write; accepts with or without on read.
    static func encode(_ file: BackupFile) throws -> Data {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        jsonEncoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601WithFractionalSeconds.string(from: date))
        }
        return try jsonEncoder.encode(file)
    }

    static func decode(_ data: Data) throws -> BackupFile {
        // Check the version first so a newer format gives a clear error rather than a decode failure.
        struct Header: Decodable { var version: Int }
        let plain = JSONDecoder()
        guard let header = try? plain.decode(Header.self, from: data) else {
            throw BackupError.unreadable("missing version")
        }
        guard header.version >= 1 else { throw BackupError.unreadable("invalid version \(header.version)") }
        guard header.version <= BackupFile.currentVersion else { throw BackupError.unsupportedVersion(header.version) }

        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = iso8601WithFractionalSeconds.date(from: text) ?? iso8601.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
        }
        do {
            return try jsonDecoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.unreadable(error.localizedDescription)
        }
    }

    /// Imports a backup. Merge skips rides already present (same title + start minute, the
    /// DataDeduper key); Replace deletes everything first.
    @discardableResult
    static func importBackup(_ file: BackupFile, into context: ModelContext, mode: ImportMode) -> ImportSummary {
        var summary = ImportSummary(replaced: mode == .replace)
        if mode == .replace { DataMaintenance.deleteAll(context) }

        var programsByID: [String: Program] = [:]
        for program in (try? context.fetch(FetchDescriptor<Program>())) ?? [] {
            programsByID[programID(program.title)] = programsByID[programID(program.title)] ?? program
        }
        var existingKeys = Set(((try? context.fetch(FetchDescriptor<Workout>())) ?? []).map(DataDeduper.key))

        func program(for id: String?) -> Program? {
            guard let id else { return nil }
            if let existing = programsByID[id] { return existing }
            let dto = file.programs.first { $0.id == id }
            let imported = Program(title: dto?.title ?? id, type: dto.flatMap { WorkoutType(rawValue: $0.type) })
            context.insert(imported)
            programsByID[id] = imported
            summary.programsAdded += 1
            return imported
        }

        for dto in file.programs where programsByID[dto.id] == nil { _ = program(for: dto.id) }

        for dto in file.workouts {
            let title = dto.programID.flatMap { id in file.programs.first { $0.id == id }?.title } ?? dto.programID ?? "Untitled Ride"
            let key = DataDeduper.key(title: title, date: dto.date)
            if existingKeys.contains(key) {
                summary.workoutsSkipped += 1
                continue
            }
            let workout = Workout(date: dto.date, program: program(for: dto.programID),
                            durationMinutes: dto.durationMinutes, distanceMiles: dto.distanceMiles,
                            calories: dto.calories, elevationFeet: dto.elevationFeet, avgRPM: dto.avgRPM,
                            avgWatts: dto.avgWatts, inclineAvg: dto.inclineAvg, inclineMax: dto.inclineMax,
                            resistanceAvg: dto.resistanceAvg, resistanceMax: dto.resistanceMax,
                            notes: dto.notes, isSimulated: dto.isSimulated)
            workout.photoData = dto.photoData
            restoreThumbnailFocus(from: dto, to: workout)
            context.insert(workout)
            existingKeys.insert(key)
            summary.workoutsAdded += 1
        }
        try? context.save()
        DataDeduper.run(context)
        return summary
    }

    private static func restoreThumbnailFocus(from dto: WorkoutDTO, to workout: Workout) {
        guard dto.photoData != nil, let version = dto.thumbnailFocusAnalysisVersion else { return }
        workout.thumbnailFocus = dto.thumbnailFocus?.rect
        workout.thumbnailFocusAnalysisVersion = version
    }

    static func defaultFilename(now: Date = .now) -> String {
        let date = now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        return "FitnessTracker Backup " + date
    }
}

// MARK: - FileDocument for fileExporter

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
