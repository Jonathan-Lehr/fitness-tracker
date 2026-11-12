import XCTest
import SwiftUI
@testable import FitnessTracker

/// Pins each asset catalog color to the RGB values the code used before the move (#34), so the
/// catalog can't drift silently. Update the expectations here when a color is tuned on purpose.
final class AppColorTests: XCTestCase {
    private struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    private let tolerance = 0.002

    private var expectedLight: [AppColor: RGB] {
        [
            .tagEndurance: RGB(red: 0.20, green: 0.47, blue: 0.80),
            .tagClimb: RGB(red: 0.82, green: 0.29, blue: 0.62),
            .tagInterval: RGB(red: 0.89, green: 0.38, blue: 0.27),
            .tagRecovery: RGB(red: 0.49, green: 0.39, blue: 0.76),
            .tagTempo: RGB(red: 0.84, green: 0.60, blue: 0.15),
            .tagOther: RGB(red: 0.27, green: 0.59, blue: 0.35),
            .smallDipYellow: RGB(red: 0.78, green: 0.53, blue: 0.0),
        ]
    }

    /// Tags use the same value in dark mode for now; the small-dip color matches system yellow.
    private var expectedDark: [AppColor: RGB] {
        var dark = expectedLight
        dark[.smallDipYellow] = RGB(red: 1.0, green: 214.0 / 255.0, blue: 10.0 / 255.0)
        return dark
    }

    func testEveryColorHasLightExpectation() {
        XCTAssertEqual(Set(AppColor.allCases), Set(expectedLight.keys))
    }

    func testLightValuesMatchPreviousHardcodedColors() throws {
        for appColor in AppColor.allCases {
            let expected = try XCTUnwrap(expectedLight[appColor])
            assertColor(resolvedRGB(appColor, dark: false), equals: expected, "\(appColor) light")
        }
    }

    func testDarkValuesMatchPreviousHardcodedColors() throws {
        for appColor in AppColor.allCases {
            let expected = try XCTUnwrap(expectedDark[appColor])
            assertColor(resolvedRGB(appColor, dark: true), equals: expected, "\(appColor) dark")
        }
    }

    func testSmallDipDarkMatchesSystemYellow() {
        assertColor(
            resolvedRGB(.smallDipYellow, dark: true),
            equals: resolvedSystemYellowDark,
            "smallDipYellow dark vs. system yellow"
        )
    }

    private func assertColor(_ actual: RGB, equals expected: RGB, _ message: String) {
        XCTAssertEqual(actual.red, expected.red, accuracy: tolerance, message)
        XCTAssertEqual(actual.green, expected.green, accuracy: tolerance, message)
        XCTAssertEqual(actual.blue, expected.blue, accuracy: tolerance, message)
    }

    #if os(macOS)
    private func resolvedRGB(_ appColor: AppColor, dark: Bool) -> RGB {
        resolved(NSColor(resource: appColor.resource), dark: dark)
    }

    private var resolvedSystemYellowDark: RGB {
        resolved(.systemYellow, dark: true)
    }

    private func resolved(_ color: NSColor, dark: Bool) -> RGB {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        var rgb = RGB(red: 0, green: 0, blue: 0)
        appearance.performAsCurrentDrawingAppearance {
            let srgb = color.usingColorSpace(.sRGB)!
            rgb = RGB(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent)
        }
        return rgb
    }
    #else
    private func resolvedRGB(_ appColor: AppColor, dark: Bool) -> RGB {
        resolved(UIColor(resource: appColor.resource), dark: dark)
    }

    private var resolvedSystemYellowDark: RGB {
        resolved(.systemYellow, dark: true)
    }

    private func resolved(_ color: UIColor, dark: Bool) -> RGB {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGB(red: red, green: green, blue: blue)
    }
    #endif
}
