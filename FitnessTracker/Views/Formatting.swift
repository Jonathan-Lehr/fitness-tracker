import Foundation

extension Double {
    var minutesText: String { formattedMinutes() }

    /// Duration as hours and minutes, e.g. "1h 35m" or "45m". The hour component uses
    /// grouping when it reaches four digits; minutes are always two digits or fewer.
    func formattedMinutes(locale: Locale = .current) -> String {
        let minutes = Int(rounded())
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours.formattedWholeNumber(locale: locale))h \(remainingMinutes.formattedWholeNumber(locale: locale))m"
        }
        return "\(minutes.formattedWholeNumber(locale: locale))m"
    }

    /// Miles for a single ride: always two fraction digits and no grouping, so en_US
    /// matches the previous `"%.2f"` output ("19.14", "1234.50").
    func formattedMiles(locale: Locale = .current) -> String {
        formattedNumber(fractionLength: 2, locale: locale)
    }

    /// Miles plus the `mi` unit, e.g. "19.14 mi" in en_US and "19,14 mi" in de_DE.
    func formattedMilesWithUnit(locale: Locale = .current) -> String {
        "\(formattedMiles(locale: locale)) mi"
    }

    /// A value already expressed in percent (2.6 means 2.6%), e.g. "2.6%".
    /// `FormatStyle.percent` is not used because it would multiply by 100.
    func formattedPercent(fractionLength: Int, locale: Locale = .current) -> String {
        "\(formattedNumber(fractionLength: fractionLength, locale: locale))%"
    }

    /// Locale-aware decimal formatting with a fixed fraction length and no grouping.
    /// Rounding is half away from zero so en_US matches `String(format: "%.<n>f")`.
    func formattedNumber(fractionLength: Int, locale: Locale = .current) -> String {
        formatted(
            .number
                .precision(.fractionLength(fractionLength))
                .rounded(rule: .toNearestOrAwayFromZero)
                .grouping(.never)
                .locale(locale)
        )
    }

    /// Same as `formattedNumber`, with a leading "+" for zero and positive values,
    /// matching the Compare view's previous delta strings ("+0.00", "-1.5").
    func formattedSignedNumber(fractionLength: Int, locale: Locale = .current) -> String {
        let number = abs(self).formattedNumber(fractionLength: fractionLength, locale: locale)
        return self < 0 ? "-\(number)" : "+\(number)"
    }

    /// Whole number with the locale's default grouping, after rounding half away from zero.
    func formattedWholeNumber(locale: Locale = .current) -> String {
        Int(rounded(.toNearestOrAwayFromZero)).formattedWholeNumber(locale: locale)
    }

    /// Same as `formattedWholeNumber`, with a leading "+" for zero and positive values.
    func formattedSignedWholeNumber(locale: Locale = .current) -> String {
        Int(rounded(.toNearestOrAwayFromZero)).formattedSignedWholeNumber(locale: locale)
    }
}

extension Int {
    /// Whole number with the locale's default grouping, e.g. "1,234" in en_US and "1.234" in de_DE.
    /// Four-digit values now show a separator in en_US; they previously had none.
    func formattedWholeNumber(locale: Locale = .current) -> String {
        let number = Swift.abs(self).formatted(.number.grouping(.automatic).locale(locale))
        return self < 0 ? "-\(number)" : number
    }

    /// Same as `formattedWholeNumber`, with a leading "+" for zero and positive values.
    func formattedSignedWholeNumber(locale: Locale = .current) -> String {
        let number = abs(self).formattedWholeNumber(locale: locale)
        return self < 0 ? "-\(number)" : "+\(number)"
    }
}
