import SwiftUI

/// Every custom color in the app, in one place. The values live in `Assets.xcassets` as named
/// color sets with light and dark variants, so a color can be tuned there without code changes.
/// System colors (green, red, orange, secondary, accent) are used directly and aren't listed here.
enum AppColor: CaseIterable {
    case tagEndurance
    case tagClimb
    case tagInterval
    case tagRecovery
    case tagTempo
    case tagOther
    /// Stat delta for a small decline: darker amber in light mode, where system yellow washes out,
    /// and system yellow in dark mode.
    case smallDipYellow

    var color: Color {
        Color(resource)
    }

    /// The asset catalog color set, via Xcode's generated symbols, so a missing or renamed color set
    /// fails the build instead of rendering clear.
    var resource: ColorResource {
        switch self {
        case .tagEndurance: .tagEndurance
        case .tagClimb: .tagClimb
        case .tagInterval: .tagInterval
        case .tagRecovery: .tagRecovery
        case .tagTempo: .tagTempo
        case .tagOther: .tagOther
        case .smallDipYellow: .smallDipYellow
        }
    }
}
