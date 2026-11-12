import Foundation

extension Double {
    var minutesText: String {
        let m = Int(self.rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
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
    /// Exact ties round to even (1.25 becomes "1.2"), so en_US matches `String(format: "%.<n>f")`.
    func formattedNumber(fractionLength: Int, locale: Locale = .current) -> String {
        formatted(
            .number
                .precision(.fractionLength(fractionLength))
                .rounded(rule: .toNearestOrEven)
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
}
