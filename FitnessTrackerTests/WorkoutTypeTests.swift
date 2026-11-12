import XCTest
@testable import FitnessTracker

final class WorkoutTypeTests: XCTestCase {
    func testInferMatchesEachNamedTypeCaseInsensitively() {
        XCTAssertEqual(WorkoutType.infer(from: "Mineral Bottom Endurance Ride"), .endurance)
        XCTAssertEqual(WorkoutType.infer(from: "Devils Garden INTERVAL Ride"), .interval)
        XCTAssertEqual(WorkoutType.infer(from: "Green River Recovery Ride"), .recovery)
        XCTAssertEqual(WorkoutType.infer(from: "Delicate Arch Climb"), .climb)
        XCTAssertEqual(WorkoutType.infer(from: "tempo work"), .tempo)
    }

    func testInferUsesAllCasesOrderWhenTitleContainsTwoTypes() {
        // `interval` appears before `climb` in `allCases`.
        XCTAssertEqual(WorkoutType.infer(from: "Climb Interval"), .interval)
        XCTAssertEqual(WorkoutType.infer(from: "Endurance Climb"), .endurance)
    }

    func testInferReturnsOtherWhenNoTypeKeywordMatches() {
        XCTAssertEqual(WorkoutType.infer(from: "Valley Ride"), .other)
        XCTAssertEqual(WorkoutType.infer(from: "Some Other Ride"), .other)
        XCTAssertEqual(WorkoutType.infer(from: ""), .other)
    }
}
