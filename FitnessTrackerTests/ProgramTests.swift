import XCTest
import SwiftData
@testable import FitnessTracker

@MainActor
final class ProgramTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        try TestSupport.inMemoryContext()
    }

    func testNormalizedTitleTrimsWhitespaceAndNewlines() {
        XCTAssertEqual(Program.normalizedTitle("  Hill Climb\n"), "Hill Climb")
        XCTAssertEqual(Program.normalizedTitle("\nHill Climb  "), "Hill Climb")
        XCTAssertEqual(Program.normalizedTitle("   \n  "), "")
        XCTAssertEqual(Program.normalizedTitleKey("  Hill Climb\n"), "hill climb")
        XCTAssertEqual(Program.normalizedTitleKey("HILL CLIMB"), "hill climb")
    }

    func testFindOrCreateMatchesCaseAndWhitespace() throws {
        let context = try makeContext()
        let first = Program.findOrCreate(title: "  Hill Climb  ", in: context)
        XCTAssertEqual(first.title, "Hill Climb")

        let sameCase = Program.findOrCreate(title: "hill climb", in: context)
        XCTAssertTrue(first === sameCase)

        let sameNewlines = Program.findOrCreate(title: "\nHill Climb\n", in: context)
        XCTAssertTrue(first === sameNewlines)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Program>()).count, 1)
    }

    func testFindOrCreateMatchesExistingUntrimmedTitle() throws {
        let context = try makeContext()
        let existing = Program(title: "  Hill Climb\n")
        context.insert(existing)
        let found = Program.findOrCreate(title: "hill climb", in: context)
        XCTAssertTrue(found === existing)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Program>()).count, 1)
    }

    func testFindOrCreateCreatesDistinctPrograms() throws {
        let context = try makeContext()
        let first = Program.findOrCreate(title: "Hill Climb", in: context)
        let second = Program.findOrCreate(title: "Valley Ride", in: context)
        XCTAssertFalse(first === second)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Program>()).count, 2)
    }
}
