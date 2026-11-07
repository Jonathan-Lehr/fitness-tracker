#if os(iOS)
import XCTest
import UIKit
@testable import FitnessTracker

final class OrientationLockTests: XCTestCase {
    func testPortraitOnlyAppliesToIPhoneOnly() {
        XCTAssertEqual(OrientationLock.mask(portraitOnly: true, idiom: .phone), .portrait)
        XCTAssertEqual(OrientationLock.mask(portraitOnly: true, idiom: .pad), .all)
        XCTAssertEqual(OrientationLock.mask(portraitOnly: false, idiom: .phone), .all)
    }

    @MainActor
    func testLockAndRelease() {
        OrientationLock.setPortraitOnly(true)
        let expected = OrientationLock.mask(portraitOnly: true, idiom: UIDevice.current.userInterfaceIdiom)
        XCTAssertEqual(OrientationLock.mask, expected)
        OrientationLock.setPortraitOnly(false)
        XCTAssertEqual(OrientationLock.mask, .all)
    }
}
#endif
