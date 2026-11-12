import XCTest
@testable import FitnessTracker

final class InProgressComparisonTests: XCTestCase {
    let us = Locale(identifier: "en_US")
    let german = Locale(identifier: "de_DE")

    func testChangeFormatsSignedWholePercent() {
        XCTAssertEqual(InProgressComparisonView.change(110, 100, locale: us), "+10%")
        XCTAssertEqual(InProgressComparisonView.change(90, 100, locale: us), "-10%")
        XCTAssertEqual(InProgressComparisonView.change(100, 100, locale: us), "+0%")
        XCTAssertEqual(InProgressComparisonView.change(110.4, 100, locale: us), "+10%")
        XCTAssertEqual(InProgressComparisonView.change(110.5, 100, locale: us), "+11%")
    }

    func testChangeShowsEmDashWhenPreviousIsZero() {
        XCTAssertEqual(InProgressComparisonView.change(50, 0, locale: us), "—")
        XCTAssertEqual(InProgressComparisonView.change(50, -10, locale: us), "—")
        XCTAssertEqual(InProgressComparisonView.change(0, 0, locale: us), "—")
    }

    func testChangeUsesLocaleGrouping() {
        XCTAssertEqual(InProgressComparisonView.change(11, 1, locale: us), "+1,000%")
        XCTAssertEqual(InProgressComparisonView.change(11, 1, locale: german), "+1.000%")
    }
}
