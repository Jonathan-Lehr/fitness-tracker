#if DEBUG
import SwiftUI
import SwiftData

struct DebugMenuView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClearAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Simulated Data") {
                    Button("Generate 18 Months of Rides") { SimulatedData.generate(into: context); dismiss() }
                    Button("Remove Simulated Rides", role: .destructive) {
                        SeedData.deleteAll(context, simulatedOnly: true); dismiss()
                    }
                }
                Section("Real Data") {
                    Button("Re-insert the 4 Real Rides") { SeedData.insertRealRides(context); dismiss() }
                    Button("Clear ALL Data", role: .destructive) { confirmClearAll = true }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Delete every ride and program?", isPresented: $confirmClearAll) {
                Button("Delete Everything", role: .destructive) { SeedData.deleteAll(context); dismiss() }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 320)
        #endif
    }
}
#endif
