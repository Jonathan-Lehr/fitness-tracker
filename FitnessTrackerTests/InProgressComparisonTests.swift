import XCTest
@testable import FitnessTracker

final class InProgressComparisonTests: XCTestCase {
    let usLocale = Locale(identifier: "en_US")
    let german = Locale(identifier: "de_DE")

    func testChangeFormatsSignedWholePercent() {
        XCTAssertEqual(InProgressComparisonView.change(110, 100, locale: usLocale), "+10%")
        XCTAssertEqual(InProgressComparisonView.change(90, 100, locale: usLocale), "-10%")
        XCTAssertEqual(InProgressComparisonView.change(100, 100, locale: usLocale), "+0%")
        XCTAssertEqual(InProgressComparisonView.change(110.4, 100, locale: usLocale), "+10%")
        XCTAssertEqual(InProgressComparisonView.change(110.5, 100, locale: usLocale), "+11%")
    }

    func testChangeShowsEmDashWhenPreviousIsZero() {
        XCTAssertEqual(InProgressComparisonView.change(50, 0, locale: usLocale), "—")
        XCTAssertEqual(InProgressComparisonView.change(50, -10, locale: usLocale), "—")
        XCTAssertEqual(InProgressComparisonView.change(0, 0, locale: usLocale), "—")
    }

    func testChangeUsesLocaleGrouping() {
        XCTAssertEqual(InProgressComparisonView.change(11, 1, locale: usLocale), "+1,000%")
        XCTAssertEqual(InProgressComparisonView.change(11, 1, locale: german), "+1.000%")
    }
}
