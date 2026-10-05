import SwiftUI
import Photos

/// Individual card in the Tinder-like deck displaying media preview and bottom metadata (creation date, file size).
public struct SwipeCardView: View {
    public let item: MediaItem
    public let dragOffset: CGSize

    @State private var fullImage: UIImage? = nil

    public init(item: MediaItem, dragOffset: CGSize = .zero) {
        self.item = item
        self.dragOffset = dragOffset
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background Media
                ZStack {
                    Color.black

                    if item.isVideo {
                        VideoPlayerView(asset: item.asset)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else if let image = fullImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .onAppear {
                                loadCardImage()
                            }
                    }
                }

                // Dynamic Swipe Stamp Overlays
                swipeStampOverlay

                // Bottom Metadata Drawer (Key User Requirement: creation date and file size)
                bottomMetadataDrawer
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(borderStrokeColor, lineWidth: 2.5)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 8)
        }
    }

    // MARK: - Stamp Overlays
    private var swipeStampOverlay: some View {
        ZStack {
            // Right Swipe = DELETE (Red Stamp)
            if dragOffset.width > 30 {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                            Text("DELETE")
                        }
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.red, lineWidth: 3.5)
                        )
                        .rotationEffect(.degrees(12))
                        .opacity(min(Double(dragOffset.width) / 100.0, 1.0))
                        .padding(20)
                    }
                    Spacer()
                }
            }

            // Left Swipe = KEEP (Green Stamp)
            if dragOffset.width < -30 {
                VStack {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("KEEP")
                        }
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.green, lineWidth: 3.5)
                        )
                        .rotationEffect(.degrees(-12))
                        .opacity(min(Double(-dragOffset.width) / 100.0, 1.0))
                        .padding(20)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Bottom Metadata Drawer
    private var bottomMetadataDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                // Large File Size Badge
                HStack(spacing: 6) {
                    Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(item.formattedFileSize)
                        .font(.system(size: 20, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.fileSizeBytes > 100 * 1024 * 1024 ? Color.red.opacity(0.85) : Color.blue.opacity(0.85))
                )

                Spacer()

                // Media Type / Duration
                if item.isVideo {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text(item.formattedDuration)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                }
            }

            // Creation Date and Resolution (Requested by user)
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(item.formattedDate)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "aspectratio")
                    Text(item.resolutionString)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.75), Color.black.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var borderStrokeColor: Color {
        if dragOffset.width > 60 {
            return Color.red.opacity(0.8)
        } else if dragOffset.width < -60 {
            return Color.green.opacity(0.8)
        } else {
            return Color.white.opacity(0.18)
        }
    }

    private func loadCardImage() {
        PhotoLibraryManager.shared.requestThumbnail(
            for: item.asset,
            targetSize: CGSize(width: 800, height: 1200)
        ) { img in
            self.fullImage = img
        }
    }
}
