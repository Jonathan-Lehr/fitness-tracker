import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export / import of all rides as a versioned JSON backup.
struct BackupView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var workouts: [Workout]

    @State private var includeSimulated = false
    @State private var importMode: ImportMode = .merge
    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var confirmReplace = false
    @State private var pendingImport: BackupFile?
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private var realCount: Int { workouts.filter { !$0.isSimulated }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Include simulated rides", isOn: $includeSimulated)
                    Button {
                        startExport()
                    } label: {
                        Label("Export Backup…", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Export")
                } footer: {
                    Text("Saves \(includeSimulated ? workouts.count : realCount) rides, with photos, to a JSON file.")
                }

                Section {
                    Picker("When importing", selection: $importMode) {
                        ForEach(ImportMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Backup…", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Import")
                } footer: {
                    Text(importMode == .merge
                         ? "Adds rides from the file and skips ones you already have (same program and start time)."
                         : "Deletes all current rides and programs, then loads the file.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Backup & Restore")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .backupExporter(isPresented: $showExporter, document: exportDocument) { result in
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("Replace all data with this backup?", isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("Replace All", role: .destructive) { applyPendingImport() }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("All current rides will be deleted first. Export a backup now if you might need them.")
            }
            .alert("Import Complete", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
                Button("OK") {}
            } message: { Text(resultMessage ?? "") }
            .alert("Backup Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: { Text(errorMessage ?? "") }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
    }

    private func startExport() {
        do {
            let data = try BackupService.encode(BackupService.makeBackup(context, includeSimulated: includeSimulated))
            exportDocument = BackupDocument(data: data)
            showExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let file = try BackupService.decode(try Data(contentsOf: url))
            pendingImport = file
            if importMode == .replace { confirmReplace = true } else { applyPendingImport() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyPendingImport() {
        guard let file = pendingImport else { return }
        pendingImport = nil
        resultMessage = BackupService.importBackup(file, into: context, mode: importMode).message
    }
}

extension View {
    /// fileExporter for a backup JSON with the dated default filename.
    func backupExporter(isPresented: Binding<Bool>, document: BackupDocument?,
                        onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View {
        fileExporter(isPresented: isPresented, document: document, contentType: .json,
                     defaultFilename: BackupService.defaultFilename(), onCompletion: onCompletion)
    }
}
