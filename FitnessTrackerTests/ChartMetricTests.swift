import XCTest
@testable import FitnessTracker

final class ChartMetricTests: XCTestCase {
    private let calendar = Calendar.app
    private let usLocale = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    private func makeWorkout(day: Int, distanceMiles: Double = 10, avgRPM: Int = 75, avgWatts: Int = 85) -> Workout {
        TestSupport.workout(
            date: TestSupport.date(year: 2025, month: 3, day: day, calendar: calendar),
            distanceMiles: distanceMiles,
            avgRPM: avgRPM,
            avgWatts: avgWatts
        )
    }

    func testValueReadsTheMatchingField() {
        let workout = makeWorkout(day: 1, distanceMiles: 19.14, avgRPM: 78, avgWatts: 142)
        XCTAssertEqual(ChartMetric.watts.value(workout), 142)
        XCTAssertEqual(ChartMetric.distance.value(workout), 19.14)
        XCTAssertEqual(ChartMetric.rpm.value(workout), 78)
    }

    func testBestFollowsTheMetric() {
        let mostWatts = makeWorkout(day: 1, distanceMiles: 10, avgRPM: 70, avgWatts: 150)
        let longest = makeWorkout(day: 2, distanceMiles: 20, avgRPM: 72, avgWatts: 100)
        let fastestCadence = makeWorkout(day: 3, distanceMiles: 12, avgRPM: 90, avgWatts: 110)
        let workouts = [mostWatts, longest, fastestCadence]
        XCTAssertTrue(ChartMetric.watts.best(in: workouts) === mostWatts)
        XCTAssertTrue(ChartMetric.distance.best(in: workouts) === longest)
        XCTAssertTrue(ChartMetric.rpm.best(in: workouts) === fastestCadence)
    }

    func testBestPicksTheEarliestOnATie() {
        let first = makeWorkout(day: 1, avgWatts: 120)
        let second = makeWorkout(day: 2, avgWatts: 120)
        XCTAssertTrue(ChartMetric.watts.best(in: [first, second]) === first)
    }

    func testBestIsNilWhenNoWorkoutRecordedTheMetric() {
        let workouts = [makeWorkout(day: 1, avgRPM: 0), makeWorkout(day: 2, avgRPM: 0)]
        XCTAssertNil(ChartMetric.rpm.best(in: workouts))
        XCTAssertNil(ChartMetric.watts.best(in: []))
    }

    func testRecordedSkipsMissingValues() {
        let recorded = makeWorkout(day: 1, avgRPM: 80)
        let missing = makeWorkout(day: 2, avgRPM: 0)
        let workouts = [recorded, missing]
        XCTAssertEqual(ChartMetric.rpm.recorded(in: workouts).count, 1)
        XCTAssertTrue(ChartMetric.rpm.recorded(in: workouts).first === recorded)
        XCTAssertEqual(ChartMetric.watts.recorded(in: workouts).count, 2)
    }

    func testFormattedValueIncludesTheUnit() {
        let workout = makeWorkout(day: 1, distanceMiles: 19.14, avgRPM: 78, avgWatts: 1_142)
        XCTAssertEqual(ChartMetric.watts.formattedValue(workout, locale: usLocale), "1,142 W")
        XCTAssertEqual(ChartMetric.distance.formattedValue(workout, locale: usLocale), "19.14 mi")
        XCTAssertEqual(ChartMetric.rpm.formattedValue(workout, locale: usLocale), "78 RPM")
        XCTAssertEqual(ChartMetric.distance.formattedValue(workout, locale: german), "19,14 mi")
    }
}
