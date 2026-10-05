import SwiftUI
import Photos

/// Thumbnail card displaying the image or video frame with an explicit file size badge and selection checkmark.
public struct MediaThumbnailCard: View {
    @ObservedObject var item: MediaItem
    public let isSelected: Bool
    public let onTap: () -> Void
    public let onLongPress: () -> Void

    @State private var thumbnail: UIImage? = nil
    @State private var requestID: PHImageRequestID? = nil

    public init(
        item: MediaItem,
        isSelected: Bool,
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void = {}
    ) {
        self.item = item
        self.isSelected = isSelected
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                // Background image
                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(
                            Image(systemName: item.isVideo ? "video" : "photo")
                                .foregroundColor(.secondary)
                        )
                }

                // Selection Overlay
                if isSelected {
                    Color.blue.opacity(0.35)
                }

                // Top-Left: Video Duration or Screenshot tag
                VStack {
                    HStack {
                        if item.isVideo {
                            HStack(spacing: 4) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 9))
                                Text(item.formattedDuration)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Capsule())
                        } else if item.isScreenshot {
                            Image(systemName: "iphone")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Circle())
                        }
                        Spacer()

                        // Selection Checkmark (Top-Right)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.red)
                                .background(Circle().fill(Color.white).padding(2))
                        }
                    }
                    Spacer()
                }
                .padding(6)

                // Bottom-Right: File Size Badge (Key User Request)
                HStack(spacing: 3) {
                    Text(item.formattedFileSize)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(sizeBadgeColor.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.red : Color.white.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            cancelThumbnail()
        }
    }

    private var sizeBadgeColor: Color {
        let mb = Double(item.fileSizeBytes) / (1024.0 * 1024.0)
        if mb >= 100 {
            return Color.red // Very large file (> 100MB)
        } else if mb >= 25 {
            return Color.orange // Moderately large file
        } else {
            return Color.black // Standard size
        }
    }

    private func loadThumbnail() {
        guard thumbnail == nil else { return }
        requestID = PhotoLibraryManager.shared.requestThumbnail(for: item.asset) { image in
            self.thumbnail = image
        }
    }

    private func cancelThumbnail() {
        if let id = requestID {
            PhotoLibraryManager.shared.imageManager.cancelImageRequest(id)
            requestID = nil
        }
    }
}
