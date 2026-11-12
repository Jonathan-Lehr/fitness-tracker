import XCTest
@testable import FitnessTracker

final class ImportSummaryTests: XCTestCase {
    func testMessageForSingleRideAdded() {
        XCTAssertEqual(ImportSummary(workoutsAdded: 1).message, "1 ride added.")
    }

    func testMessageForZeroAndPluralRidesAdded() {
        XCTAssertEqual(ImportSummary().message, "0 rides added.")
        XCTAssertEqual(ImportSummary(workoutsAdded: 4).message, "4 rides added.")
    }

    func testMessageIncludesSkippedDuplicates() {
        XCTAssertEqual(
            ImportSummary(workoutsAdded: 1, workoutsSkipped: 1).message,
            "1 ride added, 1 duplicate skipped."
        )
        XCTAssertEqual(
            ImportSummary(workoutsAdded: 1, workoutsSkipped: 4).message,
            "1 ride added, 4 duplicates skipped."
        )
    }

    func testMessageIncludesNewPrograms() {
        XCTAssertEqual(
            ImportSummary(workoutsAdded: 1, programsAdded: 1).message,
            "1 ride added, 1 new program."
        )
        XCTAssertEqual(
            ImportSummary(workoutsAdded: 2, programsAdded: 3).message,
            "2 rides added, 3 new programs."
        )
    }

    func testMessagePrefixesReplaceMode() {
        XCTAssertEqual(
            ImportSummary(workoutsAdded: 4, replaced: true).message,
            "Replaced all data. 4 rides added."
        )
        XCTAssertEqual(
            ImportSummary(workoutsAdded: 1, workoutsSkipped: 0, programsAdded: 1, replaced: true).message,
            "Replaced all data. 1 ride added, 1 new program."
        )
    }
}
