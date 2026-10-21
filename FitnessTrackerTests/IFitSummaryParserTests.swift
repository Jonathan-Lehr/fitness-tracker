import XCTest
@testable import FitnessTracker

struct ExpectedRide {
    let file: String
    let title: String
    let y, mo, d, h, mi: Int
    let minutes: Double, miles: Double
    let cal, ft, rpm, watts: Int
    let incAvg, incMax: Double
    let resAvg, resMax: Int

    static let all: [ExpectedRide] = [
        ExpectedRide(file: "ride-2026-10-12", title: "Green River Recovery Ride", y: 2026, mo: 10, d: 12, h: 14, mi: 54,
                     minutes: 42, miles: 10.02, cal: 310, ft: 599, rpm: 79, watts: 79, incAvg: 1.0, incMax: 9.0, resAvg: 11, resMax: 16),
        ExpectedRide(file: "ride-2026-10-15", title: "Hurrah Pass Endurance Ride", y: 2026, mo: 10, d: 15, h: 12, mi: 34,
                     minutes: 65, miles: 13.88, cal: 499, ft: 1745, rpm: 77, watts: 85, incAvg: 2.6, incMax: 10.0, resAvg: 10, resMax: 16),
        ExpectedRide(file: "ride-2026-10-18", title: "Devils Garden Interval Ride", y: 2026, mo: 10, d: 18, h: 15, mi: 35,
                     minutes: 46, miles: 9.50, cal: 385, ft: 1543, rpm: 74, watts: 97, incAvg: 3.7, incMax: 12.0, resAvg: 9, resMax: 15),
        ExpectedRide(file: "ride-2026-10-20", title: "Mineral Bottom Endurance Ride", y: 2026, mo: 10, d: 20, h: 16, mi: 6,
                     minutes: 48, miles: 9.85, cal: 376, ft: 1542, rpm: 75, watts: 88, incAvg: 3.6, incMax: 10.0, resAvg: 8, resMax: 15),
    ]

    /// Returns a list of human-readable mismatches (empty = all correct).
    func mismatches(_ s: IFitSummary, calendar: Calendar = .current) -> [String] {
        var out: [String] = []
        func check<T: Equatable>(_ name: String, _ got: T?, _ want: T) {
            if got != want { out.append("\(name): got \(got.map { "\($0)" } ?? "nil"), want \(want)") }
        }
        func checkD(_ name: String, _ got: Double?, _ want: Double) {
            if got == nil || abs(got! - want) > 0.001 { out.append("\(name): got \(got.map { "\($0)" } ?? "nil"), want \(want)") }
        }
        check("title", s.title, title)
        check("date", s.date, calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!)
        checkD("duration", s.durationMinutes, minutes)
        checkD("distance", s.distanceMiles, miles)
        check("calories", s.calories, cal)
        check("elevation", s.elevationFeet, ft)
        check("rpm", s.avgRPM, rpm)
        check("watts", s.avgWatts, watts)
        checkD("inclineAvg", s.inclineAvg, incAvg)
        checkD("inclineMax", s.inclineMax, incMax)
        check("resistanceAvg", s.resistanceAvg, resAvg)
        check("resistanceMax", s.resistanceMax, resMax)
        return out
    }
}

final class IFitSummaryParserTests: XCTestCase {
    /// Approximate OCR output: noisy header, a button on the title line, tokens split
    /// across lines, and chart axis labels that must be ignored.
    static let fixtures: [String: [String]] = [
        "ride-2026-10-12": [
            "×", "Nice job!", "Keep up the great work",
            "Green River Recovery Ride", "Repeat workout",
            "Last completed 2:54 PM - Oct 12, 2026",
            "42 min", "10.02 mi", "310", "cals (est)", "599 ft", "79 avg rpm", "79 avg watts",
            "9 %", "16", "4 %", "8", "-3 %", "0",
            "Incline 1.0 % avg · 9.0 % max", "Resistance 11 avg · 16 max", "NordicTrack", "iFIT",
        ],
        "ride-2026-10-15": [
            "Nice job!", "Keep up the great work", "Extend your workout",
            "Hurrah Pass Endurance Ride",
            "Last completed 12:34 PM - Oct 15, 2026",
            "1 hr 5 min 13.88 mi 499 cals (est) 1745 ft 77 avg rpm 85 avg watts",
            "16", "10 %", "8", "4 %", "-2 %", "0",
            "Incline", "2.6 % avg", "10.0 % max", "Resistance", "10 avg", "16 max",
        ],
        "ride-2026-10-18": [
            "Nice job!", "eep up the great work",
            "Devils Garden Interval Ride Repeat workout",
            "Last completed 3:35 PM – Oct 18, 2026",
            "46 min", "9.50 mi", "385 cals (est)", "1543 ft", "74 avg rpm", "97 avg watts",
            "12 %", "15", "4 %", "8", "-3 %", "1",
            "Incline 3.7 % avg • 12.0 % max", "Resistance 9 avg • 15 max",
        ],
        "ride-2026-10-20": [
            "Nice job!", "Keep up the great work",
            "Mineral Bottom Endurance Ride", "Repeat workout",
            "Last completed 4:06 PM - Oct 20, 2026",
            "48 min 9.85 mi", "376 cals (est)", "1542 ft", "75 avg rpm 88 avg watts",
            "10 %", "15", "3 %", "7", "-3 %", "0",
            "Incline 3.6 % avg", "10.0 % max", "Resistance 8 avg", "15 max",
        ],
    ]

    func testFixtures() {
        for ride in ExpectedRide.all {
            let s = IFitSummaryParser.parse(lines: Self.fixtures[ride.file]!)
            XCTAssertEqual(ride.mismatches(s), [], ride.file)
            XCTAssertTrue(s.missingFields.isEmpty, ride.file)
        }
    }

    func testMissingFieldsAreReported() {
        let s = IFitSummaryParser.parse(lines: ["Some Program Ride", "Last completed 1:00 PM - Jan 2, 2026", "30 min"])
        XCTAssertEqual(s.title, "Some Program Ride")
        XCTAssertEqual(s.durationMinutes, 30)
        XCTAssertTrue(s.missingFields.contains(.watts))
        XCTAssertFalse(s.missingFields.contains(.date))
    }

    func testHoursOnlyDuration() {
        XCTAssertEqual(IFitSummaryParser.parse(lines: ["1 hr"]).durationMinutes, 60)
    }

    func testTitleByProximity() {
        let items = [
            RecognizedText(text: "Devils Garden Interval Ride", box: CGRect(x: 0.02, y: 0.38, width: 0.2, height: 0.025)),
            RecognizedText(text: "Repeat workout", box: CGRect(x: 0.84, y: 0.37, width: 0.1, height: 0.02)),
            RecognizedText(text: "Last completed 3:35 PM - Oct 18, 2026", box: CGRect(x: 0.02, y: 0.42, width: 0.15, height: 0.012)),
        ]
        XCTAssertEqual(IFitSummaryParser.titleByProximity(items), "Devils Garden Interval Ride")
    }
}

/// Runs real Vision OCR on the sample photos. Reports every mismatch plus the OCR lines.
final class PhotoOCRIntegrationTests: XCTestCase {
    func testRealPhotos() throws {
        let bundle = Bundle(for: Self.self)
        var report: [String] = []
        var correctFields = 0, totalFields = 0
        for ride in ExpectedRide.all {
            guard let url = bundle.url(forResource: ride.file, withExtension: "jpg") else {
                XCTFail("Missing test resource \(ride.file).jpg"); continue
            }
            let data = try Data(contentsOf: url)
            guard let image = ImageTools.cgImage(from: data) else { XCTFail("Undecodable \(ride.file)"); continue }
            let items = try TextRecognizer.recognize(image)
            let summary = IFitSummaryParser.parse(items: items)
            let problems = ride.mismatches(summary)
            totalFields += 12
            correctFields += 12 - problems.count
            if !problems.isEmpty {
                report.append("\(ride.file):\n  " + problems.joined(separator: "\n  ")
                              + "\n  OCR lines:\n    " + IFitSummaryParser.groupIntoLines(items).joined(separator: "\n    "))
            }
        }
        print("OCR accuracy: \(correctFields)/\(totalFields) fields")
        XCTAssertTrue(report.isEmpty, "OCR accuracy \(correctFields)/\(totalFields)\n" + report.joined(separator: "\n"))
    }
}
