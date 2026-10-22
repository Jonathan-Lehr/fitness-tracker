import XCTest
@testable import FitnessTracker

/// Synthetic camera-capture OCR variants for distance and elevation.
final class NoisyOCRTests: XCTestCase {
    private func parse(_ lines: [String]) -> IFitSummary { IFitSummaryParser.parse(lines: lines) }

    private let header = ["Hurrah Pass Endurance Ride", "Last completed 12:34 PM - Oct 15, 2026"]
    private let tail = ["499 cals (est)", "1745 ft", "77 avg rpm", "85 avg watts"]

    func testDistanceVariants() {
        let variants: [(String, Double)] = [
            ("13.88 mi", 13.88), ("13.88mi", 13.88), ("13,88 mi", 13.88), ("13 88 mi", 13.88),
            ("1388 mi", 13.88), ("13.88 ml", 13.88), ("13.88 rni", 13.88), ("13.88 mI", 13.88),
            ("l3.88 mi", 13.88), ("1O.O2 mi", 10.02), ("9.5O mi", 9.50), ("13.88 mi.", 13.88),
            ("13.88", 13.88),          // unit lost entirely
            ("13.88 rn", 13.88),       // unit garbled beyond recognition
        ]
        for (token, want) in variants {
            let s = parse(header + ["1 hr 5 min", token] + tail)
            XCTAssertEqual(s.distanceMiles ?? -1, want, accuracy: 0.001, "distance from '\(token)'")
            XCTAssertEqual(s.elevationFeet, 1745, "elevation alongside '\(token)'")
        }
    }

    func testDistanceUnitOnSeparateLaterLine() {
        // Perspective skew: "mi" grouped with a different line than its value.
        let s = parse(header + ["1 hr 5 min 13.88", "499 cals (est) 1745 ft 77 avg rpm 85 avg watts", "mi"])
        XCTAssertEqual(s.distanceMiles ?? -1, 13.88, accuracy: 0.001)
    }

    func testDistanceRejectsOutOfRange() {
        let s = parse(header + ["1 hr 5 min", "99.99 mi"] + tail)
        XCTAssertNil(s.distanceMiles)
    }

    func testElevationVariants() {
        let variants: [(String, Int)] = [
            ("1745 ft", 1745), ("1745ft", 1745), ("1,745 ft", 1745), ("1.745 ft", 1745), ("1 745 ft", 1745),
            ("1745 f t", 1745), ("1745 ff", 1745), ("1745 fl", 1745), ("l745 ft", 1745), ("17O5 ft", 1705),
            ("1745", 1745),            // unit missing
            ("1745 #", 1745),          // unit garbled
            ("599 ft", 599),
        ]
        for (token, want) in variants {
            let s = parse(header + ["1 hr 5 min", "13.88 mi", "499 cals (est)", token, "77 avg rpm", "85 avg watts"])
            XCTAssertEqual(s.elevationFeet, want, "elevation from '\(token)'")
            XCTAssertEqual(s.distanceMiles ?? -1, 13.88, accuracy: 0.001, "distance alongside '\(token)'")
            XCTAssertEqual(s.calories, 499, "calories alongside '\(token)'")
            XCTAssertEqual(s.avgRPM, 77, "rpm alongside '\(token)'")
        }
    }

    func testElevationRejectsOutOfRange() {
        let s = parse(header + ["13.88 mi", "499 cals (est)", "45000 ft", "77 avg rpm"])
        XCTAssertNil(s.elevationFeet)
    }

    func testGeometryPairsUnitOnlyObservations() {
        // Value and unit are separate observations; skew puts "mi"/"ft" slightly lower.
        let items = [
            RecognizedText(text: "Hurrah Pass Endurance Ride", box: CGRect(x: 0.04, y: 0.30, width: 0.2, height: 0.03)),
            RecognizedText(text: "Last completed 12:34 PM - Oct 15, 2026", box: CGRect(x: 0.04, y: 0.34, width: 0.15, height: 0.012)),
            RecognizedText(text: "13.88", box: CGRect(x: 0.20, y: 0.37, width: 0.06, height: 0.03)),
            RecognizedText(text: "mi", box: CGRect(x: 0.265, y: 0.395, width: 0.02, height: 0.018)),
            RecognizedText(text: "499 cals (est)", box: CGRect(x: 0.30, y: 0.36, width: 0.1, height: 0.03)),
            RecognizedText(text: "1,745", box: CGRect(x: 0.44, y: 0.355, width: 0.05, height: 0.03)),
            RecognizedText(text: "ft", box: CGRect(x: 0.495, y: 0.38, width: 0.015, height: 0.018)),
            RecognizedText(text: "77 avg rpm", box: CGRect(x: 0.53, y: 0.35, width: 0.08, height: 0.03)),
        ]
        let s = IFitSummaryParser.parse(items: items)
        XCTAssertEqual(s.distanceMiles ?? -1, 13.88, accuracy: 0.001)
        XCTAssertEqual(s.elevationFeet, 1745)
    }

    func testValueLeftOf() {
        let items = [
            RecognizedText(text: "9.50", box: CGRect(x: 0.2, y: 0.4, width: 0.05, height: 0.03)),
            RecognizedText(text: "mi", box: CGRect(x: 0.255, y: 0.41, width: 0.02, height: 0.02)),
        ]
        XCTAssertEqual(IFitSummaryParser.valueLeftOf(unitPattern: IFitSummaryParser.miUnit, in: items), "9.50")
    }
}
