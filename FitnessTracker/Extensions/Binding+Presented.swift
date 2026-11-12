import SwiftUI

extension Binding where Value == Bool {
    /// True while `source` holds a value; dismissing the presentation clears it.
    static func isPresented<Item>(_ source: Binding<Item?>) -> Binding<Bool> {
        Binding(
            get: { source.wrappedValue != nil },
            set: { if !$0 { source.wrappedValue = nil } }
        )
    }
}
