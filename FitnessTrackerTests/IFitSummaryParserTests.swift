import XCTest
@testable import FitnessTracker

struct ExpectedWorkout {
    let file: String
    let title: String
    let year, month, day, hour, minute: Int
    let minutes: Double, miles: Double
    let calories: Int, elevationFeet: Int, rpm: Int, watts: Int
    let inclineAvg: Double, inclineMax: Double
    let resistanceAvg: Int, resistanceMax: Int

    static let all: [ExpectedWorkout] = [
        ExpectedWorkout(file: "workout-2026-10-12", title: "Green River Recovery Ride", year: 2026, month: 10, day: 12, hour: 14, minute: 54,
                     minutes: 42, miles: 10.02, calories: 310, elevationFeet: 599, rpm: 79, watts: 79, inclineAvg: 1.0, inclineMax: 9.0, resistanceAvg: 11, resistanceMax: 16),
        ExpectedWorkout(file: "workout-2026-10-15", title: "Hurrah Pass Endurance Ride", year: 2026, month: 10, day: 15, hour: 12, minute: 34,
                     minutes: 65, miles: 13.88, calories: 499, elevationFeet: 1745, rpm: 77, watts: 85, inclineAvg: 2.6, inclineMax: 10.0, resistanceAvg: 10, resistanceMax: 16),
        ExpectedWorkout(file: "workout-2026-10-18", title: "Devils Garden Interval Ride", year: 2026, month: 10, day: 18, hour: 15, minute: 35,
                     minutes: 46, miles: 9.50, calories: 385, elevationFeet: 1543, rpm: 74, watts: 97, inclineAvg: 3.7, inclineMax: 12.0, resistanceAvg: 9, resistanceMax: 15),
        ExpectedWorkout(file: "workout-2026-10-20", title: "Mineral Bottom Endurance Ride", year: 2026, month: 10, day: 20, hour: 16, minute: 6,
                     minutes: 48, miles: 9.85, calories: 376, elevationFeet: 1542, rpm: 75, watts: 88, inclineAvg: 3.6, inclineMax: 10.0, resistanceAvg: 8, resistanceMax: 15),
    ]

    /// Returns a list of human-readable mismatches (empty = all correct).
    /// Allowed incline error in percent points for real-photo OCR.
    private var inclineTolerance: Double { 0.3 + 0.001 }

    func mismatches(_ summary: IFitSummary, calendar: Calendar = .current) -> [String] {
        var failures: [String] = []
        func check<T: Equatable>(_ name: String, _ actual: T?, _ expected: T) {
            if actual != expected { failures.append("\(name): got \(actual.map { "\($0)" } ?? "nil"), want \(expected)") }
        }
        func checkD(_ name: String, _ actual: Double?, _ expected: Double, tolerance: Double = 0.001) {
            if actual == nil || abs(actual! - expected) > tolerance { failures.append("\(name): got \(actual.map { "\($0)" } ?? "nil"), want \(expected)") }
        }
        check("title", summary.title, title)
        check("date", summary.date, calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!)
        checkD("duration", summary.durationMinutes, minutes)
        checkD("distance", summary.distanceMiles, miles)
        check("calories", summary.calories, calories)
        check("elevation", summary.elevationFeet, elevationFeet)
        check("rpm", summary.avgRPM, rpm)
        check("watts", summary.avgWatts, watts)
        // OCR can misread a single incline digit (macOS 26 reads "2.6" as "28" -> 2.8), so allow ±0.3.
        checkD("inclineAvg", summary.inclineAvg, inclineAvg, tolerance: inclineTolerance)
        checkD("inclineMax", summary.inclineMax, inclineMax, tolerance: inclineTolerance)
        check("resistanceAvg", summary.resistanceAvg, resistanceAvg)
        check("resistanceMax", summary.resistanceMax, resistanceMax)
        return failures
    }
}

final class IFitSummaryParserTests: XCTestCase {
    /// Approximate OCR output: noisy header, a button on the title line, tokens split
    /// across lines, and chart axis labels that must be ignored.
    static let fixtures: [String: [String]] = [
        "workout-2026-10-12": [
            "×", "Nice job!", "Keep up the great work",
            "Green River Recovery Ride", "Repeat workout",
            "Last completed 2:54 PM - Oct 12, 2026",
            "42 min", "10.02 mi", "310", "cals (est)", "599 ft", "79 avg rpm", "79 avg watts",
            "9 %", "16", "4 %", "8", "-3 %", "0",
            "Incline 1.0 % avg · 9.0 % max", "Resistance 11 avg · 16 max", "NordicTrack", "iFIT",
        ],
        "workout-2026-10-15": [
            "Nice job!", "Keep up the great work", "Extend your workout",
            "Hurrah Pass Endurance Ride",
            "Last completed 12:34 PM - Oct 15, 2026",
            "1 hr 5 min 13.88 mi 499 cals (est) 1745 ft 77 avg rpm 85 avg watts",
            "16", "10 %", "8", "4 %", "-2 %", "0",
            "Incline", "2.6 % avg", "10.0 % max", "Resistance", "10 avg", "16 max",
        ],
        "workout-2026-10-18": [
            "Nice job!", "eep up the great work",
            "Devils Garden Interval Ride Repeat workout",
            "Last completed 3:35 PM – Oct 18, 2026",
            "46 min", "9.50 mi", "385 cals (est)", "1543 ft", "74 avg rpm", "97 avg watts",
            "12 %", "15", "4 %", "8", "-3 %", "1",
            "Incline 3.7 % avg • 12.0 % max", "Resistance 9 avg • 15 max",
        ],
        "workout-2026-10-20": [
            "Nice job!", "Keep up the great work",
            "Mineral Bottom Endurance Ride", "Repeat workout",
            "Last completed 4:06 PM - Oct 20, 2026",
            "48 min 9.85 mi", "376 cals (est)", "1542 ft", "75 avg rpm 88 avg watts",
            "10 %", "15", "3 %", "7", "-3 %", "0",
            "Incline 3.6 % avg", "10.0 % max", "Resistance 8 avg", "15 max",
        ],
    ]

    func testFixtures() {
        for workout in ExpectedWorkout.all {
            let summary = IFitSummaryParser.parse(lines: Self.fixtures[workout.file]!)
            XCTAssertEqual(workout.mismatches(summary), [], workout.file)
            XCTAssertTrue(summary.missingFields.isEmpty, workout.file)
        }
    }

    func testMissingFieldsAreReported() {
        let summary = IFitSummaryParser.parse(lines: ["Some Program Ride", "Last completed 1:00 PM - Jan 2, 2026", "30 min"])
        XCTAssertEqual(summary.title, "Some Program Ride")
        XCTAssertEqual(summary.durationMinutes, 30)
        XCTAssertTrue(summary.missingFields.contains(.watts))
        XCTAssertFalse(summary.missingFields.contains(.date))
    }

    func testInclineRestoresDroppedDecimal() {
        XCTAssertEqual(IFitSummaryParser.inclinePercent("28"), 2.8)
        XCTAssertEqual(IFitSummaryParser.inclinePercent("2.6"), 2.6)
        XCTAssertEqual(IFitSummaryParser.inclinePercent("10.0"), 10.0)
        XCTAssertEqual(IFitSummaryParser.inclinePercent("12"), 12)
        XCTAssertEqual(IFitSummaryParser.inclinePercent("20"), 20)
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
        for workout in ExpectedWorkout.all {
            guard let url = bundle.url(forResource: workout.file, withExtension: "jpg") else {
                XCTFail("Missing test resource \(workout.file).jpg")
                continue
            }
            let data = try Data(contentsOf: url)
            guard let image = ImageTools.cgImage(from: data) else {
                XCTFail("Undecodable \(workout.file)")
                continue
            }
            // Same path as import: the straightened copy is used when it reads at least as many fields.
            let reading = try OCRReading.bestReading(of: image)
            let straightened = ScreenStraightener.straightened(image) != nil
            print("Straightened \(workout.file): \(straightened ? "yes" : "no")")
            let items = reading.items
            let summary = reading.summary
            let problems = workout.mismatches(summary)
            totalFields += 12
            correctFields += 12 - problems.count
            if !problems.isEmpty {
                report.append("\(workout.file):\n  " + problems.joined(separator: "\n  ")
                              + "\n  OCR lines:\n    " + IFitSummaryParser.groupIntoLines(items).joined(separator: "\n    "))
            }
        }
        print("OCR accuracy: \(correctFields)/\(totalFields) fields")
        XCTAssertTrue(report.isEmpty, "OCR accuracy \(correctFields)/\(totalFields)\n" + report.joined(separator: "\n"))
    }
}
