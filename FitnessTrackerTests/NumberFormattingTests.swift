import XCTest
@testable import FitnessTracker

final class NumberFormattingTests: XCTestCase {
    let us = Locale(identifier: "en_US")
    let german = Locale(identifier: "de_DE")

    func testUSOutputMatchesPreviousStringFormat() {
        let samples: [(Double, Int)] = [
            (0, 0), (0, 1), (0, 2),
            (19.14, 2), (2.6, 1), (8, 1),
            (45, 0), (1234, 0), (1234.5, 2),
            (1.25, 1), (1.25, 2), (1.5, 0),
            (-1.5, 1), (-19.14, 2),
        ]
        for (value, fractionLength) in samples {
            let expected = String(format: "%.\(fractionLength)f", value)
            XCTAssertEqual(
                value.formattedNumber(fractionLength: fractionLength, locale: us),
                expected,
                "\(value) at \(fractionLength) fraction digits"
            )
        }
    }

    func testUSSignedDeltasMatchPreviousStringFormat() {
        let samples: [(Double, Int)] = [
            (0, 0), (0, 1), (0, 2),
            (0.4, 2), (12, 0), (1.5, 1),
            (-1.5, 1), (-19.14, 2), (-8, 0),
        ]
        for (value, fractionLength) in samples {
            let expected = (value >= 0 ? "+" : "") + String(format: "%.\(fractionLength)f", value)
            XCTAssertEqual(
                value.formattedSignedNumber(fractionLength: fractionLength, locale: us),
                expected,
                "signed \(value) at \(fractionLength) fraction digits"
            )
        }
    }

    func testUSMilesAndInclineMatchPreviousOutput() {
        XCTAssertEqual((19.14).formattedMiles(locale: us), "19.14")
        XCTAssertEqual((19.14).formattedMilesWithUnit(locale: us), "19.14 mi")
        XCTAssertEqual((0).formattedMiles(locale: us), "0.00")
        XCTAssertEqual((1234.5).formattedMilesWithUnit(locale: us), "1234.50 mi")
        XCTAssertEqual((2.6).formattedPercent(fractionLength: 1, locale: us), "2.6%")
        XCTAssertEqual((8.0).formattedPercent(fractionLength: 1, locale: us), "8.0%")
        XCTAssertEqual(inclineRange(average: 2.6, maximum: 8.0, locale: us), "2.6% / 8.0%")
    }

    func testGermanLocaleUsesCommaDecimalSeparator() {
        XCTAssertEqual((19.14).formattedMiles(locale: german), "19,14")
        XCTAssertEqual((19.14).formattedMilesWithUnit(locale: german), "19,14 mi")
        XCTAssertEqual((0).formattedMiles(locale: german), "0,00")
        XCTAssertEqual((1234.5).formattedMilesWithUnit(locale: german), "1234,50 mi")
        XCTAssertEqual((2.6).formattedPercent(fractionLength: 1, locale: german), "2,6%")
        XCTAssertEqual((8.0).formattedPercent(fractionLength: 1, locale: german), "8,0%")
        XCTAssertEqual(inclineRange(average: 2.6, maximum: 8.0, locale: german), "2,6% / 8,0%")
        XCTAssertEqual((1234).formattedNumber(fractionLength: 0, locale: german), "1234")
        XCTAssertEqual((1.5).formattedSignedNumber(fractionLength: 1, locale: german), "+1,5")
        XCTAssertEqual((-1.5).formattedSignedNumber(fractionLength: 1, locale: german), "-1,5")
        XCTAssertEqual((0).formattedSignedNumber(fractionLength: 2, locale: german), "+0,00")
    }

    private func inclineRange(average: Double, maximum: Double, locale: Locale) -> String {
        "\(average.formattedPercent(fractionLength: 1, locale: locale)) / \(maximum.formattedPercent(fractionLength: 1, locale: locale))"
    }
}
