import SwiftUI
import AVFoundation

/// Redesigned finish and export sheet after completing a drawing session.
/// Supports saving clean camera timelapse video and composite artwork photo.
public struct FinishExportSheet: View {
    @ObservedObject var viewModel: TraceViewModel
    @Environment(\.dismiss) private var dismiss
    public let onReturnHome: () -> Void

    @State private var didSavePhoto: Bool = false
    @State private var isSavingPhoto: Bool = false

    @State private var didSaveVideo: Bool = false
    @State private var isSavingVideo: Bool = false

    @State private var didSaveBoth: Bool = false
    @State private var isSavingBoth: Bool = false

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header Stats Badge
                    headerStatsCard

                    // 1. Timelapse Video Card (Clean camera feed, if recorded)
                    if let videoURL = viewModel.recordedVideoURL {
                        timelapseVideoCard(url: videoURL)
                    }

                    // 2. Artwork Composite Card
                    if let composite = viewModel.compositeImage {
                        artworkPhotoCard(image: composite)
                    }

                    // Save Both Button (If both are available and neither has been saved)
                    if viewModel.recordedVideoURL != nil && viewModel.compositeImage != nil && (!didSavePhoto || !didSaveVideo) {
                        Button(action: {
                            Task {
                                isSavingBoth = true
                                var photoSuccess = true
                                var videoSuccess = true

                                if !didSavePhoto {
                                    photoSuccess = await viewModel.saveCompositeToPhotos()
                                    if photoSuccess { didSavePhoto = true }
                                }

                                if let videoURL = viewModel.recordedVideoURL, !didSaveVideo {
                                    videoSuccess = await viewModel.saveVideoToPhotos(url: videoURL)
                                    if videoSuccess { didSaveVideo = true }
                                }

                                isSavingBoth = false
                                if photoSuccess && videoSuccess {
                                    didSaveBoth = true
                                    HapticService.shared.notification(.success)
                                }
                            }
                        }) {
                            HStack(spacing: 10) {
                                if isSavingBoth {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: didSaveBoth ? "checkmark.circle.fill" : "square.and.arrow.down.on.square.fill")
                                        .font(.headline)
                                }
                                Text(didSaveBoth ? "Saved Everything to Photos! 🎉" : "Save Both (Video + Photo) to Photos")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: didSaveBoth ? [Color.green, Color.green.opacity(0.85)] : [Color(red: 0.54, green: 0.28, blue: 0.98), Color(red: 0.0, green: 0.76, blue: 0.86)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSavingBoth || didSaveBoth)
                        .padding(.top, 4)
                    }

                    // Return Home Button
                    Button(action: {
                        dismiss()
                        onReturnHome()
                    }) {
                        Text("Finish & Return to Home")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 10)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle("Drawing Complete")
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

    // MARK: - Header Stats Card
    private var headerStatsCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Great work!")
                    .font(.system(size: 18, weight: .bold))
                HStack(spacing: 12) {
                    Label(viewModel.formattedElapsed, systemImage: "clock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    if viewModel.recordedVideoURL != nil {
                        Label(viewModel.formattedRecordingElapsed, systemImage: "video.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.red)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Timelapse Video Card
    private func timelapseVideoCard(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "video.badge.checkmark")
                        .foregroundColor(.red)
                    Text("Drawing Timelapse Video")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
                Text(viewModel.formattedRecordingElapsed)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                    .foregroundColor(.red)
            }

            Text("Clean camera feed of your drawing session (no UI or photo overlay)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                // Save Video Button
                Button(action: {
                    Task {
                        isSavingVideo = true
                        let success = await viewModel.saveVideoToPhotos(url: url)
                        isSavingVideo = false
                        if success { didSaveVideo = true }
                    }
                }) {
                    HStack(spacing: 8) {
                        if isSavingVideo {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: didSaveVideo ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 15))
                        }
                        Text(didSaveVideo ? "Saved Video!" : "Save Video")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(didSaveVideo ? Color.green : Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isSavingVideo || didSaveVideo)

                // Share Video Button
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 48, height: 46)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Artwork Photo Card
    private func artworkPhotoCard(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                        .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
                    Text("Artwork Photo Capture")
                        .font(.system(size: 16, weight: .bold))
                }
                Spacer()
            }

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 10) {
                // Save Photo Button
                Button(action: {
                    Task {
                        isSavingPhoto = true
                        let success = await viewModel.saveCompositeToPhotos()
                        isSavingPhoto = false
                        if success { didSavePhoto = true }
                    }
                }) {
                    HStack(spacing: 8) {
                        if isSavingPhoto {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: didSavePhoto ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 15))
                        }
                        Text(didSavePhoto ? "Saved Photo!" : "Save Photo")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(didSavePhoto ? Color.green : Color(red: 0.54, green: 0.28, blue: 0.98))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isSavingPhoto || didSavePhoto)

                // Share Photo Button
                ShareLink(item: Image(uiImage: image), preview: SharePreview("TraceCam Artwork", image: Image(uiImage: image))) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 48, height: 46)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.2), lineWidth: 1)
        )
    }
}
