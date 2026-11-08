import XCTest
@testable import FitnessTracker

final class WattsAxisTests: XCTestCase {
    func testEmptyOrInvalidReturnsNil() {
        XCTAssertNil(WattsAxis.domain(for: []))
        XCTAssertNil(WattsAxis.domain(for: [0, -10, .nan, .infinity]))
    }

    func testFitsDataWithPaddingAndRounding() {
        // span 30 -> pad max(3, 5) = 5 -> 115...155
        XCTAssertEqual(WattsAxis.domain(for: [120, 135, 150]), 115...155)
    }

    func testLargeSpanUsesTenPercentPadding() {
        // span 200 -> pad 20 -> 80...320
        XCTAssertEqual(WattsAxis.domain(for: [100, 300]), 80...320)
    }

    func testSingleAndConstantValuesGetVisibleRange() {
        XCTAssertEqual(WattsAxis.domain(for: [142]), 135...150)
        XCTAssertEqual(WattsAxis.domain(for: [142, 142, 142]), 135...150)
    }

    func testIgnoresZeroAndInvalidAlongsideValidValues() {
        XCTAssertEqual(WattsAxis.domain(for: [0, 120, .nan, 150]), 115...155)
    }

    func testNeverBelowZero() {
        XCTAssertEqual(WattsAxis.domain(for: [3]), 0...10)
    }

    func testRangeContainsAllValidValues() {
        let values: [Double] = [97.3, 101.8, 133.2, 88.9]
        let d = WattsAxis.domain(for: values)!
        XCTAssertTrue(values.allSatisfy { d.contains($0) })
        XCTAssertLessThan(d.lowerBound, 88.9)
    }
}
