import Foundation

extension Double {
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

    /// Miles for a single ride: always two fraction digits and no grouping, so a value
    /// like 1234.5 stays "1234.50" in en_US instead of "1,234.50".
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
    /// Exact ties round to even (1.25 becomes "1.2"), matching `String(format:)` so tests
    /// and display stay consistent in en_US.
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
    /// so Compare deltas read as "+0.00" or "-1.5".
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

/// A localized string with Foundation's automatic grammar agreement applied, for text that
/// isn't shown through SwiftUI `Text` (which applies it on its own). Mark the count and noun
/// with `^[\(count) ride](inflect: true)` to get "1 ride" and "2 rides".
func inflected(_ resource: String.LocalizationValue, locale: Locale = .current) -> String {
    String(AttributedString(localized: resource, locale: locale).characters)
}

/// Average watts with a unit, or `placeholder` when there is no value.
/// Call sites pass "—" or "— W" because list, grid, and detail use different empty states.
func formattedAverageWatts(_ watts: Double?, placeholder: String, locale: Locale = .current) -> String {
    watts.map { "\($0.formattedWholeNumber(locale: locale)) W" } ?? placeholder
}
