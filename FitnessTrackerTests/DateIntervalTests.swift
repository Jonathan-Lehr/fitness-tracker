import XCTest
@testable import FitnessTracker

final class DateIntervalTests: XCTestCase {
    func testHalfOpenContainsIncludesStartAndExcludesEnd() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)
        let interval = DateInterval(start: start, end: end)

        XCTAssertTrue(interval.halfOpenContains(start))
        XCTAssertTrue(interval.halfOpenContains(Date(timeIntervalSince1970: 1_500)))
        XCTAssertFalse(interval.halfOpenContains(end))
        XCTAssertFalse(interval.halfOpenContains(Date(timeIntervalSince1970: 999)))

        // Foundation's contains is closed on the end, which is why the helper exists.
        XCTAssertTrue(interval.contains(end))
        XCTAssertFalse(interval.halfOpenContains(end))
    }
}
