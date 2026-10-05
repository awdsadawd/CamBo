import SwiftUI
import Photos

/// Review screen shown after clicking Done or finishing a swipe session.
/// Allows users to view all items selected for deletion, keep items manually, or delete all at once.
public struct DeletionReviewView: View {
    @ObservedObject var viewModel: SwipeCleanViewModel
    public let onFinishedDeletions: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showConfirmDeleteAlert: Bool = false

    public init(viewModel: SwipeCleanViewModel, onFinishedDeletions: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onFinishedDeletions = onFinishedDeletions
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.swipedDeletedItems.isEmpty {
                    emptyReviewView
                } else {
                    // Header Reclaim Summary Banner
                    reclaimSummaryHeader

                    // Scrollable List of Items Marked for Deletion
                    List {
                        Section {
                            ForEach(viewModel.swipedDeletedItems) { item in
                                reviewItemRow(item: item)
                            }
                        } header: {
                            Text("Items Marked For Deletion (\(viewModel.swipedDeletedItems.count))")
                                .font(.caption.weight(.semibold))
                        } footer: {
                            Text("Tapping 'Keep' removes the item from the deletion list and keeps it safely in your library.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())

                    // Bottom Delete All Action Bar
                    bottomDeleteActionBar
                }
            }
            .navigationTitle("Review Deletions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep All & Exit") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Deletion", isPresented: $showConfirmDeleteAlert) {
                Button("Delete \(viewModel.swipedDeletedItems.count) Items (\(viewModel.formattedDeletedSize))", role: .destructive) {
                    Task {
                        let success = await viewModel.confirmDeleteAll()
                        if success {
                            onFinishedDeletions()
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will move \(viewModel.swipedDeletedItems.count) items (\(viewModel.formattedDeletedSize)) to your 'Recently Deleted' album.")
            }
        }
    }

    // MARK: - Reclaim Summary Header
    private var reclaimSummaryHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "trash.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.formattedDeletedSize)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.red)
                Text("\(viewModel.swipedDeletedItems.count) items selected to delete")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Review Item Row
    private func reviewItemRow(item: MediaItem) -> some View {
        HStack(spacing: 12) {
            // Thumbnail with size overlay
            ZStack(alignment: .bottomTrailing) {
                MediaRowThumbnail(asset: item.asset)
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if item.isVideo {
                    Text(item.formattedDuration)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(3)
                }
            }

            // Info Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.formattedFileSize)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)

                    if item.fileSizeBytes > 100 * 1024 * 1024 {
                        Text("LARGE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }

                Text(item.formattedDate)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text(item.resolutionString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()

            // Keep Manually Button (User Request: "or keep them manually on there")
            Button(action: {
                viewModel.keepItemManually(item: item)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .bold))
                    Text("Keep")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Bottom Delete Action Bar
    private var bottomDeleteActionBar: some View {
        VStack(spacing: 8) {
            Button(action: {
                showConfirmDeleteAlert = true
            }) {
                HStack(spacing: 8) {
                    if viewModel.isDeletingBatch {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.headline)
                    }
                    Text("Delete All (\(viewModel.formattedDeletedSize))")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.red.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .disabled(viewModel.isDeletingBatch)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Empty Review View
    private var emptyReviewView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.green)
            }

            Text("No Items to Delete")
                .font(.system(size: 22, weight: .bold))

            Text("You didn't mark any photos or videos for deletion in this session.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Done") {
                dismiss()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(Capsule())
            .padding(.top, 12)
        }
        .padding(32)
    }
}

/// Helper thumbnail row loader for the review screen.
private struct MediaRowThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
                    .onAppear {
                        PhotoLibraryManager.shared.requestThumbnail(for: asset, targetSize: CGSize(width: 140, height: 140)) { img in
                            self.image = img
                        }
                    }
            }
        }
    }
}
