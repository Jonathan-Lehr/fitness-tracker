import SwiftUI

/// Card fill matching the Log List's rows (inset grouped on iOS, inset list on macOS), plus the
/// page color to put behind cards so they stand out in both light and dark mode.
enum LogSurface {
    #if os(macOS)
    static let card = Color(nsColor: NSColor.alternatingContentBackgroundColors.last ?? .controlBackgroundColor)
    static let page = Color(nsColor: .windowBackgroundColor)
    #else
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let page = Color(uiColor: .systemGroupedBackground)
    #endif
}
