import SwiftUI

/// Export and save confirmation sheet after finishing a drawing session.
public struct FinishExportSheet: View {
    @ObservedObject var viewModel: TraceViewModel
    @Environment(\.dismiss) private var dismiss
    public let onReturnHome: () -> Void

    @State private var didSave: Bool = false
    @State private var isSaving: Bool = false
    @State private var showShareSheet: Bool = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let composite = viewModel.compositeImage {
                    // Preview Card
                    VStack(spacing: 8) {
                        Image(uiImage: composite)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(radius: 8)

                        Text("Composite Capture")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                } else {
                    ProgressView("Generating composite...")
                        .frame(height: 240)
                }

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            isSaving = true
                            let success = await viewModel.saveCompositeToPhotos()
                            isSaving = false
                            if success {
                                didSave = true
                            }
                        }
                    }) {
                        HStack(spacing: 10) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: didSave ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                                    .font(.headline)
                            }
                            Text(didSave ? "Saved to Photos!" : "Save to Photos Library")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(didSave ? Color.green : Color(red: 0.54, green: 0.28, blue: 0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isSaving || didSave)

                    if let composite = viewModel.compositeImage {
                        ShareLink(item: Image(uiImage: composite), preview: SharePreview("TraceCam Artwork", image: Image(uiImage: composite))) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share with Friends")
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Button("Return to Home") {
                        dismiss()
                        onReturnHome()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle("Tracing Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Tracing") {
                        dismiss()
                    }
                }
            }
        }
    }
}
