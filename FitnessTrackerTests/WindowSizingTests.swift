#if os(macOS)
import XCTest
@testable import FitnessTracker

@MainActor
final class WindowSizingTests: XCTestCase {
    func testNarrowMinWidthIsSaneAndBelowWideBreakpoint() {
        let narrowMinWidth = PeriodSummaryCard.narrowMinWidth
        print("narrowMinWidth = \(narrowMinWidth)")
        XCTAssertGreaterThan(narrowMinWidth, 150)
        XCTAssertLessThan(narrowMinWidth, 560)   // below the 6-column (wide) breakpoint
    }

    func testMinWidthAddsChrome() {
        XCTAssertEqual(WindowSizing.minWidth(chrome: 50), (PeriodSummaryCard.narrowMinWidth + 50).rounded(.up))
        XCTAssertEqual(WindowSizing.minWidth(chrome: 0),
                       (PeriodSummaryCard.narrowMinWidth + WindowSizing.fallbackChrome).rounded(.up))
    }

    func testDefaultHeightIsEightyPercentOfVisible() {
        let size = WindowSizing.defaultSize(visible: CGRect(x: 0, y: 0, width: 1512, height: 944))
        XCTAssertEqual(size.height, 755)
        XCTAssertEqual(WindowSizing.defaultSize(visible: CGRect(x: 0, y: 0, width: 800, height: 400)).height,
                       WindowSizing.minHeight)
    }
}
#endif
