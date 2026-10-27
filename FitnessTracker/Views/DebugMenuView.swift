#if DEBUG
import SwiftUI
import SwiftData

struct DebugMenuView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Destructive/data-changing debug actions; each one offers a backup first.
    private enum Action: Identifiable {
        case generate, removeSimulated, clearAll
        var id: Self { self }
        var title: String {
            switch self {
            case .generate: "Generate simulated rides?"
            case .removeSimulated: "Remove simulated rides?"
            case .clearAll: "Delete every ride and program?"
            }
        }
        var confirm: String {
            switch self {
            case .generate: "Generate"
            case .removeSimulated: "Remove"
            case .clearAll: "Delete Everything"
            }
        }
    }

    @State private var pending: Action?
    @State private var actionAfterBackup: Action?
    @State private var backupDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showBackup = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Backup") {
                    Button("Backup & Restore…") { showBackup = true }
                }
                Section("Simulated Data") {
                    Button("Generate 18 Months of Rides") { pending = .generate }
                    Button("Remove Simulated Rides", role: .destructive) { pending = .removeSimulated }
                }
                Section("Real Data") {
                    Button("Re-insert the 4 Real Rides") { SeedData.insertRealRides(context); dismiss() }
                    Button("Clear ALL Data", role: .destructive) { pending = .clearAll }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog(pending?.title ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible, presenting: pending) { action in
                Button("Back Up First…") { backUpThen(action) }
                Button(action.confirm, role: action == .generate ? nil : .destructive) { perform(action) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This changes your ride data. You can export a JSON backup first and restore it later.")
            }
            .backupExporter(isPresented: $showExporter, document: backupDocument) { result in
                // Only continue with the action if the backup was actually saved.
                if case .success = result, let action = actionAfterBackup { perform(action) }
                actionAfterBackup = nil
            }
            .sheet(isPresented: $showBackup) { BackupView() }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }

    private func backUpThen(_ action: Action) {
        guard let data = try? BackupService.encode(BackupService.makeBackup(context)) else { return }
        backupDocument = BackupDocument(data: data)
        actionAfterBackup = action
        showExporter = true
    }

    private func perform(_ action: Action) {
        switch action {
        case .generate: SimulatedData.generate(into: context)
        case .removeSimulated: SeedData.deleteAll(context, simulatedOnly: true)
        case .clearAll: SeedData.deleteAll(context)
        }
        dismiss()
    }
}
#endif
