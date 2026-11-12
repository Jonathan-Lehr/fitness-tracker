import XCTest
import CoreGraphics
@testable import FitnessTracker

final class ScreenStraightenerTests: XCTestCase {
    private func quadrilateral(_ topLeft: (Double, Double), _ topRight: (Double, Double),
                               _ bottomRight: (Double, Double), _ bottomLeft: (Double, Double)) -> ScreenQuadrilateral {
        ScreenQuadrilateral(topLeft: CGPoint(x: topLeft.0, y: topLeft.1), topRight: CGPoint(x: topRight.0, y: topRight.1),
                            bottomRight: CGPoint(x: bottomRight.0, y: bottomRight.1),
                            bottomLeft: CGPoint(x: bottomLeft.0, y: bottomLeft.1))
    }

    private var square: ScreenQuadrilateral { quadrilateral((0.1, 0.9), (0.9, 0.9), (0.9, 0.1), (0.1, 0.1)) }
    /// Shot from the left: the right edge is shorter.
    private var angled: ScreenQuadrilateral { quadrilateral((0.05, 0.95), (0.9, 0.85), (0.9, 0.15), (0.05, 0.05)) }

    func testAreaUsesShoelaceFormula() {
        XCTAssertEqual(square.area, 0.64, accuracy: 1e-9)
        // Trapezoid: parallel sides 0.9 and 0.7, width 0.85.
        XCTAssertEqual(angled.area, (0.9 + 0.7) / 2 * 0.85, accuracy: 1e-9)
    }

    func testSkewIsZeroForSquareScreen() {
        XCTAssertEqual(square.skew, 0, accuracy: 1e-9)
        XCTAssertEqual(angled.skew, 0.1, accuracy: 1e-9)
    }

    func testStraightensOnlyConfidentLargeAngledScreens() {
        XCTAssertTrue(ScreenStraightener.shouldStraighten(angled, confidence: 0.9))
        XCTAssertFalse(ScreenStraightener.shouldStraighten(angled, confidence: 0.5), "low confidence")
        XCTAssertFalse(ScreenStraightener.shouldStraighten(square, confidence: 0.95), "already square")
        let small = quadrilateral((0.4, 0.6), (0.6, 0.58), (0.6, 0.42), (0.4, 0.4))
        XCTAssertFalse(ScreenStraightener.shouldStraighten(small, confidence: 0.95), "too small")
    }

    func testFlatImageIsNotStraightened() {
        var pixels = [UInt8](repeating: 128, count: 200 * 100 * 4)
        let context = CGContext(data: &pixels, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 800,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        XCTAssertNil(ScreenStraightener.straightened(context.makeImage()!))
    }

    private func reading(fields: Int) -> OCRReading {
        var summary = IFitSummary()
        let setters: [(inout IFitSummary) -> Void] = [
            { $0.title = "Ride" }, { $0.date = .now }, { $0.durationMinutes = 30 }, { $0.distanceMiles = 8 },
            { $0.calories = 300 }, { $0.elevationFeet = 500 }, { $0.avgRPM = 75 }, { $0.avgWatts = 90 },
            { $0.inclineAvg = 2 }, { $0.inclineMax = 8 }, { $0.resistanceAvg = 10 }, { $0.resistanceMax = 14 },
        ]
        for setter in setters.prefix(fields) { setter(&summary) }
        return OCRReading(items: [], summary: summary)
    }

    func testPrefersStraightenedReadingUnlessItFoundFewerFields() {
        let original = reading(fields: 10)
        XCTAssertEqual(OCRReading.preferred(original: original, straightened: reading(fields: 12)).recognizedFieldCount, 12)
        var tie = reading(fields: 10)
        tie.summary.title = "Straightened"
        XCTAssertEqual(OCRReading.preferred(original: original, straightened: tie).summary.title, "Straightened")
        XCTAssertEqual(OCRReading.preferred(original: original, straightened: reading(fields: 9)).recognizedFieldCount, 10)
        XCTAssertEqual(OCRReading.preferred(original: original, straightened: nil).recognizedFieldCount, 10)
    }
}
