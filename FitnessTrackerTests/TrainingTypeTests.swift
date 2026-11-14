import XCTest
@testable import FitnessTracker

final class TrainingTypeTests: XCTestCase {
    func testInferMatchesEachNamedTypeCaseInsensitively() {
        XCTAssertEqual(TrainingType.infer(from: "Mineral Bottom Endurance Ride"), .endurance)
        XCTAssertEqual(TrainingType.infer(from: "Devils Garden INTERVAL Ride"), .interval)
        XCTAssertEqual(TrainingType.infer(from: "Green River Recovery Ride"), .recovery)
        XCTAssertEqual(TrainingType.infer(from: "Delicate Arch Climb"), .climb)
        XCTAssertEqual(TrainingType.infer(from: "tempo work"), .tempo)
    }

    func testInferUsesAllCasesOrderWhenTitleContainsTwoTypes() {
        // `interval` appears before `climb` in `allCases`.
        XCTAssertEqual(TrainingType.infer(from: "Climb Interval"), .interval)
        XCTAssertEqual(TrainingType.infer(from: "Endurance Climb"), .endurance)
    }

    func testInferReturnsOtherWhenNoTypeKeywordMatches() {
        XCTAssertEqual(TrainingType.infer(from: "Valley Ride"), .other)
        XCTAssertEqual(TrainingType.infer(from: "Some Other Ride"), .other)
        XCTAssertEqual(TrainingType.infer(from: ""), .other)
    }
}
