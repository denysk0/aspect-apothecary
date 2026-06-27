import PhotosUI
import SwiftUI
import UIKit

struct ScanView: View {
    @Environment(GameState.self) private var game
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                introPanel
                pickerPanel
                if game.isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Reading the object…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let outcome = game.lastScan {
                    resultPanel(outcome)
                }
            }
            .padding(20)
        }
        .background(ApothecaryBackground())
        .navigationTitle("Scanning Bench")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await scan(from: newItem) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let cg = image.cgImage {
                    Task { await game.scanImage(cg) }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var introPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label("Aspect Scanning", systemImage: "camera.viewfinder")
                    .font(.headline)
                AIBadge(.vision)
            }
            Text("Photograph a real object. The bench recognizes it on-device and distills its essences into aspects, once per kind of object.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }

    private var pickerPanel: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(game.isScanning)

            Button {
                showCamera = true
            } label: {
                Label("Take a Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(game.isScanning || !cameraAvailable)

            if !cameraAvailable {
                Text("Camera isn't available here, use the library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resultPanel(_ outcome: GameState.ScanOutcome) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Result", systemImage: "sparkles")
                .font(.headline)

            if !outcome.labels.isEmpty {
                HStack(spacing: 6) {
                    Text("Recognized:")
                        .font(.footnote.weight(.semibold))
                    Text(outcome.labels.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    AIBadge(.vision)
                }
            }

            HStack(alignment: .top, spacing: 6) {
                if let source = outcome.source {
                    AIBadge(source)
                }
                Text(outcome.message)
                    .font(.callout)
                    .foregroundStyle(outcome.duplicate ? .secondary : .primary)
            }

            if !outcome.granted.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                    ForEach(outcome.granted, id: \.aspectID) { entry in
                        HStack(spacing: 6) {
                            Text(game.engine.graph.aspectEmoji(entry.aspectID))
                            Text(game.engine.graph.aspectName(entry.aspectID))
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                            Text("+\(entry.quantity)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(Theme.cardSunken, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }

    private func scan(from item: PhotosPickerItem) async {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: data),
            let cgImage = uiImage.cgImage
        else {
            return
        }
        await game.scanImage(cgImage)
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let dismiss: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
