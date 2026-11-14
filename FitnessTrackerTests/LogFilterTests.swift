import XCTest
@testable import FitnessTracker

final class LogFilterTests: XCTestCase {
    private let calendar = Calendar.app

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        TestSupport.date(year: year, month: month, day: day, hour: hour, calendar: calendar)
    }

    private func workout(date: Date, title: String = "Hill Climb", avgWatts: Int = 80) -> Workout {
        TestSupport.workout(date: date, program: Program(title: title), avgWatts: avgWatts)
    }

    func testDefaultFilterMatchesEveryWorkoutAndIsInactive() {
        let filter = LogFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertTrue(filter.matches(workout(date: date(year: 2026, month: 1, day: 1))))
        XCTAssertTrue(filter.matches(workout(date: date(year: 2026, month: 10, day: 20), title: "Valley Ride", avgWatts: 0)))
    }

    func testDateRangeIncludesWholeStartAndEndDays() {
        var filter = LogFilter()
        filter.useDateRange = true
        filter.startDate = date(year: 2026, month: 10, day: 12, hour: 15)
        filter.endDate = date(year: 2026, month: 10, day: 20, hour: 8)
        XCTAssertTrue(filter.isActive)

        XCTAssertTrue(filter.matches(workout(date: date(year: 2026, month: 10, day: 12, hour: 0))))
        XCTAssertTrue(filter.matches(workout(date: date(year: 2026, month: 10, day: 20, hour: 23))))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 11, hour: 23))))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 21, hour: 0))))
    }

    func testProgramTitleMatchesExactly() {
        var filter = LogFilter()
        filter.programTitle = "Hill Climb"
        let matching = workout(date: date(year: 2026, month: 10, day: 20), title: "Hill Climb")
        XCTAssertTrue(filter.matches(matching))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 20), title: "hill climb")))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 20), title: "Valley Ride")))
    }

    func testTypeMatchesInferredProgramType() {
        var filter = LogFilter()
        filter.type = .climb
        XCTAssertTrue(filter.matches(workout(date: date(year: 2026, month: 10, day: 20), title: "Hill Climb")))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 20), title: "Recovery Ride")))
    }

    func testMinWattsIncludesEqualValues() {
        var filter = LogFilter()
        filter.minWatts = 80
        XCTAssertTrue(filter.isActive)
        XCTAssertTrue(filter.matches(workout(date: date(year: 2026, month: 10, day: 20), avgWatts: 80)))
        XCTAssertTrue(filter.matches(workout(date: date(year: 2026, month: 10, day: 20), avgWatts: 90)))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 20), avgWatts: 79)))
    }

    func testCombinedFiltersMustAllMatch() {
        var filter = LogFilter()
        filter.useDateRange = true
        filter.startDate = date(year: 2026, month: 10, day: 12)
        filter.endDate = date(year: 2026, month: 10, day: 20)
        filter.programTitle = "Hill Climb"
        filter.type = .climb
        filter.minWatts = 80

        let matching = workout(date: date(year: 2026, month: 10, day: 15), title: "Hill Climb", avgWatts: 80)
        XCTAssertTrue(filter.matches(matching))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 1), title: "Hill Climb", avgWatts: 80)))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 15), title: "Valley Climb", avgWatts: 80)))
        XCTAssertFalse(filter.matches(workout(date: date(year: 2026, month: 10, day: 15), title: "Hill Climb", avgWatts: 70)))
    }
}
