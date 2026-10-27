#if os(macOS)
import XCTest
@testable import FitnessTracker

@MainActor
final class WindowSizingTests: XCTestCase {
    func testNarrowMinWidthIsSaneAndBelowWideBreakpoint() {
        let w = PeriodSummaryCard.narrowMinWidth
        print("narrowMinWidth = \(w)")
        XCTAssertGreaterThan(w, 150)
        XCTAssertLessThan(w, 560)   // below the 6-column (wide) breakpoint
    }

    func testMinWidthAddsChrome() {
        XCTAssertEqual(WindowSizing.minWidth(chrome: 50), (PeriodSummaryCard.narrowMinWidth + 50).rounded(.up))
        XCTAssertEqual(WindowSizing.minWidth(chrome: 0),
                       (PeriodSummaryCard.narrowMinWidth + WindowSizing.fallbackChrome).rounded(.up))
    }

    func testDefaultHeightIsEightyPercentOfVisible() {
        let s = WindowSizing.defaultSize(visible: CGRect(x: 0, y: 0, width: 1512, height: 944))
        XCTAssertEqual(s.height, 755)
        XCTAssertEqual(WindowSizing.defaultSize(visible: CGRect(x: 0, y: 0, width: 800, height: 400)).height,
                       WindowSizing.minHeight)
    }
}
#endif
