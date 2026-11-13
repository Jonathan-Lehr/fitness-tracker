import XCTest
@testable import FitnessTracker

final class NumberFormattingTests: XCTestCase {
    let usLocale = Locale(identifier: "en_US")
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
                value.formattedNumber(fractionLength: fractionLength, locale: usLocale),
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
                value.formattedSignedNumber(fractionLength: fractionLength, locale: usLocale),
                expected,
                "signed \(value) at \(fractionLength) fraction digits"
            )
        }
    }

    func testUSMilesAndInclineMatchPreviousOutput() {
        XCTAssertEqual((19.14).formattedMiles(locale: usLocale), "19.14")
        XCTAssertEqual((19.14).formattedMilesWithUnit(locale: usLocale), "19.14 mi")
        XCTAssertEqual((0).formattedMiles(locale: usLocale), "0.00")
        XCTAssertEqual((1234.5).formattedMilesWithUnit(locale: usLocale), "1234.50 mi")
        XCTAssertEqual((2.6).formattedPercent(fractionLength: 1, locale: usLocale), "2.6%")
        XCTAssertEqual((8.0).formattedPercent(fractionLength: 1, locale: usLocale), "8.0%")
        XCTAssertEqual(inclineRange(average: 2.6, maximum: 8.0, locale: usLocale), "2.6% / 8.0%")
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

    func testWholeNumbersUseLocaleGrouping() {
        XCTAssertEqual((1234).formattedWholeNumber(locale: usLocale), "1,234")
        XCTAssertEqual((1234).formattedWholeNumber(locale: german), "1.234")
        XCTAssertEqual((1234567).formattedWholeNumber(locale: usLocale), "1,234,567")
        XCTAssertEqual((1234567).formattedWholeNumber(locale: german), "1.234.567")
        XCTAssertEqual((800).formattedWholeNumber(locale: usLocale), "800")
        XCTAssertEqual((800).formattedWholeNumber(locale: german), "800")
        XCTAssertEqual((0).formattedWholeNumber(locale: usLocale), "0")
        XCTAssertEqual((-1234).formattedWholeNumber(locale: usLocale), "-1,234")
        XCTAssertEqual((-1234).formattedWholeNumber(locale: german), "-1.234")
        XCTAssertEqual((1234.4).formattedWholeNumber(locale: usLocale), "1,234")
        XCTAssertEqual((1234.5).formattedWholeNumber(locale: usLocale), "1,235")
    }

    func testSignedWholeNumbersUseLocaleGrouping() {
        XCTAssertEqual((1234).formattedSignedWholeNumber(locale: usLocale), "+1,234")
        XCTAssertEqual((1234).formattedSignedWholeNumber(locale: german), "+1.234")
        XCTAssertEqual((-1234).formattedSignedWholeNumber(locale: usLocale), "-1,234")
        XCTAssertEqual((-1234).formattedSignedWholeNumber(locale: german), "-1.234")
        XCTAssertEqual((0).formattedSignedWholeNumber(locale: usLocale), "+0")
    }

    func testMinutesTextGroupsLargeHourValues() {
        XCTAssertEqual((95.0).formattedMinutes(locale: usLocale), "1h 35m")
        XCTAssertEqual((45.0).formattedMinutes(locale: usLocale), "45m")
        XCTAssertEqual((1234.0 * 60).formattedMinutes(locale: usLocale), "1,234h 0m")
        XCTAssertEqual((1234.0 * 60).formattedMinutes(locale: german), "1.234h 0m")
    }

    func testFormattedAverageWattsUsesPlaceholderAndLocaleGrouping() {
        XCTAssertEqual(formattedAverageWatts(1234.4, placeholder: "—", locale: usLocale), "1,234 W")
        XCTAssertEqual(formattedAverageWatts(1234.5, placeholder: "—", locale: usLocale), "1,235 W")
        XCTAssertEqual(formattedAverageWatts(1234, placeholder: "—", locale: german), "1.234 W")
        XCTAssertEqual(formattedAverageWatts(80, placeholder: "— W", locale: usLocale), "80 W")
        XCTAssertEqual(formattedAverageWatts(nil, placeholder: "—", locale: usLocale), "—")
        XCTAssertEqual(formattedAverageWatts(nil, placeholder: "— W", locale: usLocale), "— W")
    }

    private func inclineRange(average: Double, maximum: Double, locale: Locale) -> String {
        "\(average.formattedPercent(fractionLength: 1, locale: locale)) / \(maximum.formattedPercent(fractionLength: 1, locale: locale))"
    }
}
