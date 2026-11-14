#if os(macOS)
import AppKit
import SwiftUI

/// Default and minimum Mac window size, derived from the summary card's narrow (3-column)
/// layout so the window opens as narrow as possible without breaking the card.
@MainActor enum WindowSizing {
    /// UserDefaults key for the measured horizontal space between the window's content edge and
    /// the card (TabView content + inset List margins + row padding + scroller, both sides).
    nonisolated static let chromeKey = "summaryCardHorizontalChrome"
    /// Used only until the first measurement (very first launch). An undershoot is corrected
    /// immediately: the measured value raises the window's minimum width, which grows the window.
    nonisolated static let fallbackChrome: CGFloat = 40
    nonisolated static let minHeight: CGFloat = 420
    /// Default height as a fraction of the screen's visible height (below the menu bar, above the Dock).
    nonisolated static let heightFraction: CGFloat = 0.8

    nonisolated static func chrome(_ stored: Double) -> CGFloat {
        stored > 0 ? CGFloat(stored) : fallbackChrome
    }

    /// `stored` is the measured chrome (0 = not yet measured); nil reads it from UserDefaults.
    static func minWidth(chrome stored: Double? = nil) -> CGFloat {
        let value = stored ?? UserDefaults.standard.double(forKey: chromeKey)
        return (PeriodSummaryCard.narrowMinWidth + chrome(value)).rounded(.up)
    }

    static func defaultSize(visible: CGRect) -> CGSize {
        CGSize(width: minWidth(), height: max(minHeight, (visible.height * heightFraction).rounded()))
    }

    /// Main screen's visible frame at launch (used by `.defaultSize`).
    static var defaultSizeOnMainScreen: CGSize {
        defaultSize(visible: NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 875))
    }
}

/// The card reports its laid-out width here so the window root can measure the chrome around it.
@MainActor @Observable final class SummaryCardMetrics {
    static let shared = SummaryCardMetrics()
    var cardWidth: CGFloat = 0
}

extension PeriodSummaryCard.Typography.TextStyle {
    var nsTextStyle: NSFont.TextStyle {
        switch self {
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .caption: .caption1
        case .caption2: .caption2
        }
    }
}

extension PeriodSummaryCard.Typography {
    static func pointSize(_ style: TextStyle) -> CGFloat {
        NSFont.preferredFont(forTextStyle: style.nsTextStyle).pointSize
    }

    static func preferredFont(_ style: TextStyle) -> NSFont {
        NSFont.preferredFont(forTextStyle: style.nsTextStyle)
    }

    static func systemFont(style: TextStyle, weight: Font.Weight, monospacedDigits: Bool = false) -> NSFont {
        let size = pointSize(style)
        let fontWeight = nsWeight(weight)
        if monospacedDigits {
            return NSFont.monospacedDigitSystemFont(ofSize: size, weight: fontWeight)
        }
        return NSFont.systemFont(ofSize: size, weight: fontWeight)
    }

    static var titleNSFont: NSFont { systemFont(style: titleStyle, weight: titleWeight) }
    static var statValueNSFont: NSFont { systemFont(style: statValueStyle, weight: statValueWeight, monospacedDigits: true) }
    static var statLabelNSFont: NSFont { preferredFont(statLabelStyle) }
    static var statDeltaNSFont: NSFont { systemFont(style: statDeltaStyle, weight: statDeltaWeight, monospacedDigits: true) }
    static var milesUnitNSFont: NSFont { systemFont(style: milesUnitStyle, weight: milesUnitWeight) }
    static var heroDeltaNSFont: NSFont { systemFont(style: heroDeltaStyle, weight: heroDeltaWeight, monospacedDigits: true) }
    static var milesNSFont: NSFont {
        let font = NSFont.systemFont(ofSize: milesSize, weight: nsWeight(milesWeight))
        return font.fontDescriptor.withDesign(nsDesign(milesDesign))
            .flatMap { NSFont(descriptor: $0, size: milesSize) } ?? font
    }
}

private func nsWeight(_ weight: Font.Weight) -> NSFont.Weight {
    switch weight {
    case .ultraLight: .ultraLight
    case .thin: .thin
    case .light: .light
    case .regular: .regular
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    case .heavy: .heavy
    case .black: .black
    default: .regular
    }
}

private func nsDesign(_ design: Font.Design) -> NSFontDescriptor.SystemDesign {
    switch design {
    case .default: .default
    case .serif: .serif
    case .rounded: .rounded
    case .monospaced: .monospaced
    @unknown default: .default
    }
}

extension PeriodSummaryCard {
    /// Narrowest card width at which the narrow layout fits worst-case text at full size
    /// (minimumScaleFactor stays as headroom, not relied on). Measured with the same fonts the
    /// card uses, so it tracks the system's text-style sizes.
    static var narrowMinWidth: CGFloat {
        func width(_ text: String, _ font: NSFont) -> CGFloat {
            ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }

        // Stats: .headline semibold mono digits / .caption / .caption2 medium mono digits.
        let valueFont = Typography.statValueNSFont
        let labelFont = Typography.statLabelNSFont
        let deltaFont = Typography.statDeltaNSFont
        let column = PeriodSummary.Metric.allCases.map { metric in
            let (value, delta) = worstCase(metric)
            return max(width(value, valueFont), width(metric.label, labelFont), width(delta, deltaFont))
        }.max() ?? 0
        let columnCount = CGFloat(narrowColumns)
        let grid = columnCount * column + (columnCount - 1) * columnSpacing

        // Hero (+ 16pt spacer + chart minimum of 80pt): title, big miles, delta line.
        let title = width(Typography.widestTitle, Typography.titleNSFont)
            + 6 + Typography.pointSize(Typography.filterIconStyle) * 1.3   // + filter icon
        let miles = width(Typography.widestMiles, Typography.milesNSFont)
            + 4 + width(Typography.milesUnit, Typography.milesUnitNSFont)
        let heroDelta = width(Typography.widestHeroDelta, Typography.heroDeltaNSFont)
        let heroRow = max(title, miles, heroDelta) + 16 + 80

        // Segmented Week | Month | Year picker.
        let picker = GroupingPeriod.allCases.map { width($0.rawValue, NSFont.systemFont(ofSize: NSFont.systemFontSize)) + 24 }
            .reduce(0, +)

        return ceil(max(grid, heroRow, picker))
    }

    /// Longest realistic text per stat over a 365-day window (≈ a workout a day).
    private static func worstCase(_ metric: PeriodSummary.Metric) -> (value: String, delta: String) {
        switch metric {
        case .workouts: ("888", "▲ 888")
        case .time: ("888h 88m", "▲ 888h 88m")
        case .watts: ("888 W", "▲ 888 W")
        case .rpm: ("188", "▲ 88 rpm")
        case .elevation: ("888,888 ft", "▲ 88,888 ft")
        case .calories: ("888,888", "▲ 88,888 cal")
        }
    }
}
#endif
