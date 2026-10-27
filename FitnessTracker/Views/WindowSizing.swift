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

extension PeriodSummaryCard {
    /// Narrowest card width at which the narrow layout fits worst-case text at full size
    /// (minimumScaleFactor stays as headroom, not relied on). Measured with the same fonts the
    /// card uses, so it tracks the system's text-style sizes.
    static var narrowMinWidth: CGFloat {
        func w(_ s: String, _ f: NSFont) -> CGFloat {
            ceil((s as NSString).size(withAttributes: [.font: f]).width)
        }
        func size(_ style: NSFont.TextStyle) -> CGFloat { NSFont.preferredFont(forTextStyle: style).pointSize }

        // Stats: .headline semibold mono digits / .caption / .caption2 medium mono digits.
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: size(.headline), weight: .semibold)
        let labelFont = NSFont.preferredFont(forTextStyle: .caption1)
        let deltaFont = NSFont.monospacedDigitSystemFont(ofSize: size(.caption2), weight: .medium)
        let column = PeriodSummary.Metric.allCases.map { m in
            let (value, delta) = worstCase(m)
            return max(w(value, valueFont), w(m.label, labelFont), w(delta, deltaFont))
        }.max() ?? 0
        let n = CGFloat(narrowColumns)
        let grid = n * column + (n - 1) * columnSpacing

        // Hero (+ 16pt spacer + chart minimum of 80pt): title, big miles, delta line.
        let titleFont = NSFont.systemFont(ofSize: size(.subheadline), weight: .semibold)
        let title = w("Last 365 Days", titleFont) + 6 + size(.caption1) * 1.3   // + filter icon
        let rounded = NSFont.systemFont(ofSize: 48, weight: .bold).fontDescriptor.withDesign(.rounded)
            .flatMap { NSFont(descriptor: $0, size: 48) } ?? NSFont.systemFont(ofSize: 48, weight: .bold)
        let miles = w("8888", rounded) + 4 + w("mi", NSFont.systemFont(ofSize: size(.title3), weight: .semibold))
        let heroDelta = w("−888 mi vs prior 365 days",
                          NSFont.monospacedDigitSystemFont(ofSize: size(.caption1), weight: .medium))
        let heroRow = max(title, miles, heroDelta) + 16 + 80

        // Segmented Week | Month | Year picker.
        let picker = GroupingPeriod.allCases.map { w($0.rawValue, NSFont.systemFont(ofSize: NSFont.systemFontSize)) + 24 }
            .reduce(0, +)

        return ceil(max(grid, heroRow, picker))
    }

    /// Longest realistic text per stat over a 365-day window (≈ a ride a day).
    private static func worstCase(_ m: PeriodSummary.Metric) -> (value: String, delta: String) {
        switch m {
        case .rides: ("888", "▲ 888")
        case .time: ("888h 88m", "▲ 888h 88m")
        case .watts: ("888 W", "▲ 888 W")
        case .rpm: ("188", "▲ 88 rpm")
        case .elevation: ("888888 ft", "▲ 88888 ft")
        case .calories: ("888888", "▲ 88888 cal")
        }
    }
}
#endif
