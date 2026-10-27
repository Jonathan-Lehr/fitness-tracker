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
}

enum BackupError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            "This backup was made by a newer version of FitnessTracker (format \(v)). Update the app to import it."
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
        var parts = ["\(workoutsAdded) ride\(workoutsAdded == 1 ? "" : "s") added"]
        if workoutsSkipped > 0 { parts.append("\(workoutsSkipped) duplicate\(workoutsSkipped == 1 ? "" : "s") skipped") }
        if programsAdded > 0 { parts.append("\(programsAdded) new program\(programsAdded == 1 ? "" : "s")") }
        return (replaced ? "Replaced all data. " : "") + parts.joined(separator: ", ") + "."
    }
}

enum ImportMode: String, CaseIterable, Identifiable {
    case merge = "Merge", replace = "Replace All"
    var id: String { rawValue }
}

// MARK: - Service

enum BackupService {
    static func programID(_ title: String) -> String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func makeBackup(_ context: ModelContext, includeSimulated: Bool = false, now: Date = .now) -> BackupFile {
        let workouts = ((try? context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.date)]))) ?? [])
            .filter { includeSimulated || !$0.isSimulated }
        let programs = ((try? context.fetch(FetchDescriptor<Program>(sortBy: [SortDescriptor(\.title)]))) ?? [])
            .filter { p in includeSimulated || (p.workouts ?? []).contains { !$0.isSimulated } || (p.workouts ?? []).isEmpty }
        return BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: now,
            programs: programs.map { ProgramDTO(id: programID($0.title), title: $0.title, type: $0.typeRaw) },
            workouts: workouts.map { w in
                WorkoutDTO(id: DataDeduper.key(w), programID: w.program.map { programID($0.title) },
                           date: w.date, durationMinutes: w.durationMinutes, distanceMiles: w.distanceMiles,
                           calories: w.calories, elevationFeet: w.elevationFeet, avgRPM: w.avgRPM,
                           avgWatts: w.avgWatts, inclineAvg: w.inclineAvg, inclineMax: w.inclineMax,
                           resistanceAvg: w.resistanceAvg, resistanceMax: w.resistanceMax,
                           notes: w.notes, photoData: w.photoData, isSimulated: w.isSimulated)
            })
    }

    // ISO 8601 with fractional seconds on write; accepts with or without on read.
    static func encode(_ file: BackupFile) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .custom { date, encoder in
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var c = encoder.singleValueContainer()
            try c.encode(f.string(from: date))
        }
        return try enc.encode(file)
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

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = withFraction.date(from: s) ?? ISO8601DateFormatter().date(from: s) { return d }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(s)"))
        }
        do {
            return try dec.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.unreadable(error.localizedDescription)
        }
    }

    /// Imports a backup. Merge skips rides already present (same title + start minute, the
    /// DataDeduper key); Replace deletes everything first.
    @discardableResult
    static func importBackup(_ file: BackupFile, into context: ModelContext, mode: ImportMode) -> ImportSummary {
        var summary = ImportSummary(replaced: mode == .replace)
        if mode == .replace { SeedData.deleteAll(context) }

        var programsByID: [String: Program] = [:]
        for p in (try? context.fetch(FetchDescriptor<Program>())) ?? [] {
            programsByID[programID(p.title)] = programsByID[programID(p.title)] ?? p
        }
        var existingKeys = Set(((try? context.fetch(FetchDescriptor<Workout>())) ?? []).map(DataDeduper.key))

        func program(for id: String?) -> Program? {
            guard let id else { return nil }
            if let p = programsByID[id] { return p }
            let dto = file.programs.first { $0.id == id }
            let p = Program(title: dto?.title ?? id, type: dto.flatMap { WorkoutType(rawValue: $0.type) })
            context.insert(p)
            programsByID[id] = p
            summary.programsAdded += 1
            return p
        }

        for dto in file.programs where programsByID[dto.id] == nil { _ = program(for: dto.id) }

        for dto in file.workouts {
            let title = dto.programID.flatMap { id in file.programs.first { $0.id == id }?.title } ?? dto.programID ?? "Untitled Ride"
            let key = DataDeduper.key(title: title, date: dto.date)
            if existingKeys.contains(key) { summary.workoutsSkipped += 1; continue }
            let w = Workout(date: dto.date, program: program(for: dto.programID),
                            durationMinutes: dto.durationMinutes, distanceMiles: dto.distanceMiles,
                            calories: dto.calories, elevationFeet: dto.elevationFeet, avgRPM: dto.avgRPM,
                            avgWatts: dto.avgWatts, inclineAvg: dto.inclineAvg, inclineMax: dto.inclineMax,
                            resistanceAvg: dto.resistanceAvg, resistanceMax: dto.resistanceMax,
                            notes: dto.notes, isSimulated: dto.isSimulated)
            w.photoData = dto.photoData
            context.insert(w)
            existingKeys.insert(key)
            summary.workoutsAdded += 1
        }
        try? context.save()
        DataDeduper.run(context)
        return summary
    }

    static func defaultFilename(now: Date = .now) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "FitnessTracker Backup " + f.string(from: now)
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
