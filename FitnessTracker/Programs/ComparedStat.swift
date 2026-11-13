import Foundation

/// One stat in the compare sheet: both rides' values and the change between them.
struct ComparedStat: Identifiable {
    /// Whether a higher value is an improvement. Only stats where it clearly is get green or red.
    enum Preference {
        case higherIsBetter
        case neutral
    }

    /// Which way the stat moved from the earlier ride to the later one, after rounding to the
    /// displayed precision, so a change too small to show counts as unchanged.
    enum Trend: Equatable {
        case up
        case down
        case unchanged
    }

    let label: String
    let earlierValue: Double
    let laterValue: Double
    /// Fraction digits for the change; values use `formatValue`, which may add a unit.
    let fractionLength: Int
    let preference: Preference
    let formatValue: (Double, Locale) -> String

    var id: String { label }

    var change: Double { laterValue - earlierValue }

    var trend: Trend {
        let smallestShownChange = 0.5 * pow(10, -Double(fractionLength))
        if abs(change) < smallestShownChange { return .unchanged }
        return change > 0 ? .up : .down
    }

    /// The size of the change without a sign; the arrow next to it shows the direction.
    func changeText(locale: Locale = .current) -> String {
        guard trend != .unchanged else { return "0" }
        let magnitude = abs(change)
        return fractionLength == 0
            ? magnitude.formattedWholeNumber(locale: locale)
            : magnitude.formattedNumber(fractionLength: fractionLength, locale: locale)
    }
}

/// A titled group of stats in the compare sheet.
struct ComparedSection: Identifiable {
    let title: String
    let stats: [ComparedStat]

    var id: String { title }

    /// Every section of the compare sheet, in display order.
    static func all(earlier: Workout, later: Workout) -> [ComparedSection] {
        func stat(
            _ label: String,
            _ value: (Workout) -> Double,
            fractionLength: Int = 0,
            preference: ComparedStat.Preference = .neutral,
            format: @escaping (Double, Locale) -> String
        ) -> ComparedStat {
            ComparedStat(
                label: label,
                earlierValue: value(earlier),
                laterValue: value(later),
                fractionLength: fractionLength,
                preference: preference,
                formatValue: format
            )
        }
        let wholeNumber: (Double, Locale) -> String = { value, locale in
            value.formattedWholeNumber(locale: locale)
        }
        let percent: (Double, Locale) -> String = { value, locale in
            value.formattedPercent(fractionLength: 1, locale: locale)
        }

        let effort: [ComparedStat] = [
            stat("Distance", { $0.distanceMiles }, fractionLength: 2, preference: .higherIsBetter) { value, locale in
                value.formattedMilesWithUnit(locale: locale)
            },
            stat("Duration", { $0.durationMinutes }) { value, locale in
                value.formattedMinutes(locale: locale)
            },
            stat("Calories", { Double($0.calories) }, preference: .higherIsBetter, format: wholeNumber),
            stat("Elevation", { Double($0.elevationFeet) }) { value, locale in
                "\(value.formattedWholeNumber(locale: locale)) ft"
            },
        ]
        let power: [ComparedStat] = [
            stat("Avg watts", { Double($0.avgWatts) }, preference: .higherIsBetter) { value, locale in
                "\(value.formattedWholeNumber(locale: locale)) W"
            },
            stat("Avg RPM", { Double($0.avgRPM) }, format: wholeNumber),
        ]
        let resistance: [ComparedStat] = [
            stat("Average", { Double($0.resistanceAvg) }, format: wholeNumber),
            stat("Max", { Double($0.resistanceMax) }, format: wholeNumber),
        ]
        let incline: [ComparedStat] = [
            stat("Average", { $0.inclineAvg }, fractionLength: 1, format: percent),
            stat("Max", { $0.inclineMax }, fractionLength: 1, format: percent),
        ]

        return [
            ComparedSection(title: "Effort", stats: effort),
            ComparedSection(title: "Power", stats: power),
            ComparedSection(title: "Resistance", stats: resistance),
            ComparedSection(title: "Incline", stats: incline),
        ]
    }
}
