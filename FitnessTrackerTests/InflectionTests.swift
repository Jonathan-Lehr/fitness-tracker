import XCTest
@testable import FitnessTracker

final class InflectionTests: XCTestCase {
    private let usLocale = Locale(identifier: "en_US")

    func testInflectedAgreesWithTheCount() {
        XCTAssertEqual(inflected("^[\(0) workout](inflect: true)", locale: usLocale), "0 workouts")
        XCTAssertEqual(inflected("^[\(1) workout](inflect: true)", locale: usLocale), "1 workout")
        XCTAssertEqual(inflected("^[\(2) workout](inflect: true)", locale: usLocale), "2 workouts")
    }

    func testInflectedKeepsTheSurroundingText() {
        XCTAssertEqual(
            inflected("^[\(1) field](inflect: true) couldn't be read", locale: usLocale),
            "1 field couldn't be read"
        )
        XCTAssertEqual(inflected("^[\(3) new program](inflect: true)", locale: usLocale), "3 new programs")
    }
}
