import XCTest
import SwiftUI
@testable import FitnessTracker

final class BindingPresentedTests: XCTestCase {
    func testIsPresentedIsTrueWhileValueExistsAndClearsOnDismiss() {
        var message: String? = "done"
        let source = Binding(get: { message }, set: { message = $0 })
        let presented = Binding<Bool>.isPresented(source)

        XCTAssertTrue(presented.wrappedValue)
        presented.wrappedValue = true
        XCTAssertEqual(message, "done")

        presented.wrappedValue = false
        XCTAssertNil(message)
        XCTAssertFalse(presented.wrappedValue)
    }

    func testIsPresentedStaysFalseWhenSourceIsNil() {
        var pending: Int? = nil
        let source = Binding(get: { pending }, set: { pending = $0 })
        let presented = Binding<Bool>.isPresented(source)
        XCTAssertFalse(presented.wrappedValue)
        presented.wrappedValue = false
        XCTAssertNil(pending)
    }
}
