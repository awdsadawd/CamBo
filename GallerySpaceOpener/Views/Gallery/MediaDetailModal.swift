import SwiftUI
import Photos

/// Fullscreen detail inspector for a photo or video with playback and metadata breakdown.
public struct MediaDetailModal: View {
    public let item: MediaItem
    public let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var fullImage: UIImage? = nil
    @State private var showDeleteAlert: Bool = false

    public init(item: MediaItem, onDelete: @escaping () -> Void) {
        self.item = item
        self.onDelete = onDelete
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Media Viewer
                    ZStack {
                        if item.isVideo {
                            VideoPlayerView(asset: item.asset)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let image = fullImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .onAppear {
                                    loadFullImage()
                                }
                        }
                    }

                    // Bottom Metadata Drawer
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.formattedFileSize)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                Text(item.formattedDate)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            // Delete Action Button
                            Button(action: { showDeleteAlert = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash.fill")
                                    Text("Delete")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .clipShape(Capsule())
                            }
                        }

                        Divider().background(Color.white.opacity(0.15))

                        // Tech Specs Grid
                        HStack(spacing: 20) {
                            specItem(title: "Dimensions", value: item.resolutionString, icon: "aspectratio")
                            specItem(title: "Type", value: item.isVideo ? "Video" : "Photo", icon: item.isVideo ? "video" : "photo")
                            if item.isVideo {
                                specItem(title: "Duration", value: item.formattedDuration, icon: "clock")
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                    }
                }
            }
            .alert("Delete This File?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will free up \(item.formattedFileSize) of storage.")
            }
        }
    }

    private func specItem(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func loadFullImage() {
        PhotoLibraryManager.shared.requestFullImage(for: item.asset) { img in
            self.fullImage = img
        }
    }
}
