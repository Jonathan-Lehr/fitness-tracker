import XCTest
import SwiftData
import CoreGraphics
@testable import FitnessTracker

@MainActor
final class BackupTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        try TestSupport.inMemoryContext()
    }

    func count<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    func testRoundTripEncodeDecode() throws {
        let context = try makeContext()
        SeedData.insertRealRides(context)
        let workout = try context.fetch(FetchDescriptor<Workout>()).first!
        workout.notes = "Felt strong"
        workout.photoData = Data([0xFF, 0xD8, 0xFF, 0x01])
        let backup = BackupService.makeBackup(context, now: Date(timeIntervalSince1970: 1_761_000_000.25))

        let data = try BackupService.encode(backup)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"version\" : 1"))
        XCTAssertTrue(json.contains("\"exportedAt\" : \"2025-"), json.prefix(300).description) // ISO 8601
        XCTAssertTrue(json.contains("green river recovery ride"))                             // stable program ID

        let decoded = try BackupService.decode(data)
        XCTAssertEqual(decoded, backup)
        XCTAssertEqual(decoded.programs.count, 4)
        XCTAssertEqual(decoded.workouts.count, 4)
        XCTAssertEqual(decoded.workouts.first { $0.notes == "Felt strong" }?.photoData, Data([0xFF, 0xD8, 0xFF, 0x01]))
    }

    func testExportExcludesSimulatedByDefault() throws {
        let context = try makeContext()
        SeedData.insertRealRides(context)
        let program = Program(title: "Fake Climb")
        context.insert(program)
        context.insert(TestSupport.ride(
            date: .now,
            program: program,
            durationMinutes: 1,
            distanceMiles: 1,
            calories: 1,
            elevationFeet: 1,
            avgRPM: 1,
            avgWatts: 1,
            resistanceAvg: 1,
            resistanceMax: 1,
            isSimulated: true
        ))
        XCTAssertEqual(BackupService.makeBackup(context).workouts.count, 4)
        XCTAssertEqual(BackupService.makeBackup(context).programs.count, 4)
        XCTAssertEqual(BackupService.makeBackup(context, includeSimulated: true).workouts.count, 5)
    }

    func testMergeSkipsDuplicatesAndAddsNew() throws {
        let source = try makeContext()
        SeedData.insertRealRides(source)
        let program = Program(title: "Delicate Arch Climb")
        source.insert(program)
        source.insert(TestSupport.ride(
            date: Date(timeIntervalSince1970: 1_760_500_000),
            program: program,
            durationMinutes: 35,
            distanceMiles: 7.5,
            calories: 300,
            elevationFeet: 1200,
            avgRPM: 74,
            avgWatts: 92,
            inclineAvg: 4,
            inclineMax: 12,
            resistanceAvg: 10,
            resistanceMax: 16
        ))
        let backup = try BackupService.decode(BackupService.encode(BackupService.makeBackup(source)))

        let target = try makeContext()
        SeedData.insertRealRides(target)            // already has the 4 real rides
        let summary = BackupService.importBackup(backup, into: target, mode: .merge)
        XCTAssertEqual(summary.workoutsAdded, 1)
        XCTAssertEqual(summary.workoutsSkipped, 4)
        XCTAssertEqual(summary.programsAdded, 1)
        XCTAssertEqual(try count(Workout.self, target), 5)
        XCTAssertEqual(try count(Program.self, target), 5)

        // Importing again changes nothing.
        let again = BackupService.importBackup(backup, into: target, mode: .merge)
        XCTAssertEqual(again.workoutsAdded, 0)
        XCTAssertEqual(again.workoutsSkipped, 5)
        XCTAssertEqual(try count(Workout.self, target), 5)
    }

    func testReplaceDeletesExistingFirst() throws {
        let source = try makeContext()
        SeedData.insertRealRides(source)
        let backup = BackupService.makeBackup(source)

        let target = try makeContext()
        let program = Program(title: "Something Else")
        target.insert(program)
        target.insert(TestSupport.ride(
            date: .now,
            program: program,
            durationMinutes: 1,
            distanceMiles: 1,
            calories: 1,
            elevationFeet: 1,
            avgRPM: 1,
            avgWatts: 1,
            resistanceAvg: 1,
            resistanceMax: 1
        ))
        try target.save()
        let summary = BackupService.importBackup(backup, into: target, mode: .replace)
        XCTAssertTrue(summary.replaced)
        XCTAssertEqual(summary.workoutsAdded, 4)
        XCTAssertEqual(try count(Workout.self, target), 4)
        XCTAssertEqual(try count(Program.self, target), 4)
    }

    func testVersionHandling() throws {
        let newer = #"{"version": 99, "exportedAt": "2026-10-24T12:00:00Z", "programs": [], "workouts": []}"#
        XCTAssertThrowsError(try BackupService.decode(Data(newer.utf8))) { error in
            XCTAssertEqual(error as? BackupError, .unsupportedVersion(99))
        }
        let noVersion = #"{"programs": [], "workouts": []}"#
        XCTAssertThrowsError(try BackupService.decode(Data(noVersion.utf8))) { error in
            XCTAssertEqual(error as? BackupError, .unreadable("missing version"))
        }
        // v1 without fractional seconds still decodes.
        let v1 = #"{"version": 1, "exportedAt": "2026-10-24T12:00:00Z", "programs": [{"id": "x ride", "title": "X Ride", "type": "other"}], "workouts": []}"#
        let file = try BackupService.decode(Data(v1.utf8))
        XCTAssertEqual(file.version, 1)
        XCTAssertEqual(file.programs.first?.title, "X Ride")
    }

    func testDefaultFilename() {
        let date = TestSupport.date(year: 2026, month: 10, day: 24, hour: 12, calendar: .current)
        XCTAssertEqual(BackupService.defaultFilename(now: date), "FitnessTracker Backup 2026-10-24")
    }

    func testDefaultFilenameUsesLocalDateNearMidnight() {
        let date = TestSupport.date(year: 2026, month: 10, day: 24, hour: 23, calendar: .current)
        XCTAssertEqual(BackupService.defaultFilename(now: date), "FitnessTracker Backup 2026-10-24")
    }

    // MARK: Thumbnail focus

    private let focus = CGRect(x: 0.5, y: 0.1, width: 0.2, height: 0.25)

    private func backupWithFocusedPhoto() throws -> BackupFile {
        let context = try makeContext()
        SeedData.insertRealRides(context)
        let workout = try context.fetch(FetchDescriptor<Workout>()).first!
        workout.replacePhoto(with: Data([0xFF, 0xD8, 0xFF, 0x01]), analysis: ThumbnailFocusAnalysis(focus: focus))
        // Whole seconds, since the file stores milliseconds.
        return BackupService.makeBackup(context, now: Date(timeIntervalSince1970: 1_761_000_000))
    }

    func testThumbnailFocusRoundTripsAndRestores() throws {
        let backup = try backupWithFocusedPhoto()
        let decoded = try BackupService.decode(BackupService.encode(backup))
        XCTAssertEqual(decoded, backup)
        let withPhoto = try XCTUnwrap(decoded.workouts.first { $0.photoData != nil })
        XCTAssertEqual(withPhoto.thumbnailFocus?.rect, focus)
        XCTAssertEqual(withPhoto.thumbnailFocusAnalysisVersion, ThumbnailFocusFinder.analysisVersion)
        XCTAssertTrue(decoded.workouts.filter { $0.photoData == nil }.allSatisfy { $0.thumbnailFocusAnalysisVersion == nil })

        let target = try makeContext()
        BackupService.importBackup(decoded, into: target, mode: .replace)
        let restored = try XCTUnwrap(try target.fetch(FetchDescriptor<Workout>()).first { $0.photoData != nil })
        XCTAssertEqual(restored.thumbnailFocus, focus)
        XCTAssertFalse(restored.needsThumbnailFocusAnalysis)
    }

    func testBackupWithoutThumbnailFocusDecodesAndNeedsAnalysis() throws {
        // Strip the new keys to mimic a backup written before thumbnail focus existed.
        let data = try BackupService.encode(try backupWithFocusedPhoto())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let workouts = try XCTUnwrap(json["workouts"] as? [[String: Any]])
        json["workouts"] = workouts.map { workout in
            workout.filter { $0.key != "thumbnailFocus" && $0.key != "thumbnailFocusAnalysisVersion" }
        }
        let decoded = try BackupService.decode(JSONSerialization.data(withJSONObject: json))
        let withPhoto = try XCTUnwrap(decoded.workouts.first { $0.photoData != nil })
        XCTAssertNil(withPhoto.thumbnailFocus)
        XCTAssertNil(withPhoto.thumbnailFocusAnalysisVersion)

        let target = try makeContext()
        BackupService.importBackup(decoded, into: target, mode: .replace)
        let restored = try XCTUnwrap(try target.fetch(FetchDescriptor<Workout>()).first { $0.photoData != nil })
        XCTAssertNil(restored.thumbnailFocus)
        XCTAssertTrue(restored.needsThumbnailFocusAnalysis)
    }
}
