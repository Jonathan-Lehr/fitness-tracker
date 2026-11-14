import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

/// Photo-first Add Workout: take/choose a photo of the iFit summary screen, OCR it,
/// then review the prefilled form. "Enter manually" opens the empty form.
struct AddWorkoutView: View {
    private enum Stage {
        case choose
        case processing
        /// Session is created by this presenter so the form can render immediately
        /// (see `WorkoutFormView`).
        case form(WorkoutFormEditing)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .choose
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var isDropTargeted = false
    @State private var errorMessage: String?

    private var isProcessing: Bool {
        if case .processing = stage { return true }
        return false
    }

    var body: some View {
        switch stage {
        case .form(let editing):
            WorkoutFormView(editing: editing)
        case .choose, .processing:
            chooser
        }
    }

    private var chooser: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                chooserHeader
                if isProcessing {
                    ProgressView("Reading photo…").padding()
                } else {
                    chooserSourceButtons
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.callout)
                }
                Spacer()
                Button("Enter manually") {
                    stage = .form(.manualEntry(container: context.container))
                }
                .buttonStyle(.borderless)
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Add Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 560)
        #endif
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        await process(data)
                    } else {
                        errorMessage = PhotoImportError.unreadableImage.localizedDescription
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
                pickerItem = nil
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in
                showCamera = false
                if let data { Task { await process(data) } }
            }
            .ignoresSafeArea()
        }
        #endif
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url): loadFile(url)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    private var chooserHeader: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Snap the iFit summary screen")
                .font(.title2.bold())
            Text("The numbers are read from the photo, and you can review them before saving.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var chooserSourceButtons: some View {
        VStack(spacing: 12) {
            #if os(iOS)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            #endif
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            #if os(macOS)
            Button { showFileImporter = true } label: {
                Label("Open Image File…", systemImage: "folder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            dropZone
            #endif
        }
        .frame(maxWidth: 360)
    }

    #if os(macOS)
    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
            .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
            .frame(height: 110)
            .overlay {
                Label("Drop a photo here", systemImage: "square.and.arrow.down")
                    .foregroundStyle(.secondary)
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data { Task { @MainActor in await process(data) } }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { Task { @MainActor in loadFile(url) } }
            }
            return true
        }
        return false
    }
    #endif

    private func loadFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            Task { await process(data) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func process(_ data: Data) async {
        errorMessage = nil
        stage = .processing
        do {
            let result = try await PhotoImportResult.process(imageData: data)
            stage = .form(
                .prefilled(
                    summary: result.summary,
                    photo: result.photoJPEG,
                    analysis: result.thumbnailAnalysis,
                    container: context.container
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            stage = .choose
        }
    }
}

#if os(iOS)
/// Minimal camera wrapper. Calls back with JPEG data, or nil if cancelled.
struct CameraPicker: UIViewControllerRepresentable {
    var onFinish: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (Data?) -> Void
        init(onFinish: @escaping (Data?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onFinish(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
    }
}
#endif
