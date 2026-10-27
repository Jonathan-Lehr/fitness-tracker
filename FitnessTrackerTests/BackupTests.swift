import XCTest
import SwiftData
@testable import FitnessTracker

@MainActor
final class BackupTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([Program.self, Workout.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
        return ModelContext(container)
    }

    func count<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    func testRoundTripEncodeDecode() throws {
        let context = try makeContext()
        SeedData.insertRealRides(context)
        let w = try context.fetch(FetchDescriptor<Workout>()).first!
        w.notes = "Felt strong"
        w.photoData = Data([0xFF, 0xD8, 0xFF, 0x01])
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
        let p = Program(title: "Fake Climb")
        context.insert(p)
        context.insert(Workout(date: .now, program: p, durationMinutes: 1, distanceMiles: 1, calories: 1, elevationFeet: 1,
                               avgRPM: 1, avgWatts: 1, inclineAvg: 0, inclineMax: 0, resistanceAvg: 1, resistanceMax: 1,
                               isSimulated: true))
        XCTAssertEqual(BackupService.makeBackup(context).workouts.count, 4)
        XCTAssertEqual(BackupService.makeBackup(context).programs.count, 4)
        XCTAssertEqual(BackupService.makeBackup(context, includeSimulated: true).workouts.count, 5)
    }

    func testMergeSkipsDuplicatesAndAddsNew() throws {
        let source = try makeContext()
        SeedData.insertRealRides(source)
        let p = Program(title: "Delicate Arch Climb")
        source.insert(p)
        source.insert(Workout(date: Date(timeIntervalSince1970: 1_760_500_000), program: p, durationMinutes: 35,
                              distanceMiles: 7.5, calories: 300, elevationFeet: 1200, avgRPM: 74, avgWatts: 92,
                              inclineAvg: 4, inclineMax: 12, resistanceAvg: 10, resistanceMax: 16))
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
        let p = Program(title: "Something Else")
        target.insert(p)
        target.insert(Workout(date: .now, program: p, durationMinutes: 1, distanceMiles: 1, calories: 1, elevationFeet: 1,
                              avgRPM: 1, avgWatts: 1, inclineAvg: 0, inclineMax: 0, resistanceAvg: 1, resistanceMax: 1))
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
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 24; c.hour = 12
        let d = Calendar.current.date(from: c)!
        XCTAssertEqual(BackupService.defaultFilename(now: d), "FitnessTracker Backup 2026-10-24")
    }
}
