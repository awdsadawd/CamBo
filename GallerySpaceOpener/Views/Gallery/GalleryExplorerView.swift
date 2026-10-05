import SwiftUI

/// Main gallery grid view allowing users to filter by photos/videos, sort by biggest/smallest size, and enter Tinder-like mode.
public struct GalleryExplorerView: View {
    @ObservedObject var viewModel: GalleryViewModel
    public let onOpenTinderMode: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 105, maximum: 140), spacing: 8)
    ]

    public init(viewModel: GalleryViewModel, onOpenTinderMode: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onOpenTinderMode = onOpenTinderMode
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Storage & Tinder-like Banner
                tinderLikeHeroBanner

                // Filter & Sort Pills Bar
                filterAndSortBar

                // Multi-selection Action Header (Visible when items selected)
                if viewModel.isSelectionMode {
                    selectionActionBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Main Media Grid
                ZStack {
                    Color(.systemGroupedBackground).ignoresSafeArea()

                    if viewModel.items.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(viewModel.items) { item in
                                    MediaThumbnailCard(
                                        item: item,
                                        isSelected: viewModel.selectedItemIds.contains(item.id),
                                        onTap: {
                                            if viewModel.isSelectionMode {
                                                viewModel.toggleSelection(for: item)
                                            } else {
                                                viewModel.openDetail(for: item)
                                            }
                                        },
                                        onLongPress: {
                                            viewModel.toggleSelection(for: item)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                        .refreshable {
                            await viewModel.reloadMedia(forceRefresh: true)
                        }
                    }
                }
            }
            .onAppear {
                // Re-sync from cache (cheap) so deletions made in Tinder mode are reflected
                Task { await viewModel.reloadMedia() }
            }
            .navigationTitle("Storage Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.items.isEmpty {
                        Button(action: {
                            if viewModel.isSelectionMode {
                                viewModel.clearSelection()
                            } else {
                                viewModel.selectAll()
                            }
                        }) {
                            Text(viewModel.isSelectionMode ? "Deselect" : "Select")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showDetailModal) {
                if let item = viewModel.activeDetailItem {
                    MediaDetailModal(item: item) {
                        Task { await viewModel.deleteSingleItem(item) }
                    }
                }
            }
            .alert("Delete Selected Items?", isPresented: $viewModel.showDeleteConfirmation) {
                Button("Delete (\(viewModel.formattedSelectedSize))", role: .destructive) {
                    Task { await viewModel.deleteSelectedItems() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(viewModel.selectedItemIds.count) files? This will reclaim \(viewModel.formattedSelectedSize) of storage.")
            }
            .overlay(alignment: .bottom) {
                if let toast = viewModel.toastMessage {
                    Text(toast)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.85)))
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Tinder-like Hero Banner
    private var tinderLikeHeroBanner: some View {
        Button(action: onOpenTinderMode) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pink, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Tinder-like Swipe Clean")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Text("FAST")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.pink))
                    }

                    Text("Swipe right to delete • Left to keep")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.4), Color.orange.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    // MARK: - Filter & Sort Bar
    private var filterAndSortBar: some View {
        VStack(spacing: 8) {
            // Horizontal Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MediaFilterType.allCases) { filter in
                        Button(action: {
                            viewModel.selectedFilter = filter
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: filter.iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(viewModel.selectedFilter == filter ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(viewModel.selectedFilter == filter ? Color.blue : Color(.secondarySystemBackground))
                            )
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            // Sub-bar with Sort Menu and Total Size
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(viewModel.items.count) items • \(viewModel.formattedTotalLibrarySize)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Sort Dropdown Menu
                Menu {
                    ForEach(MediaSortOption.allCases) { sort in
                        Button(action: {
                            viewModel.selectedSort = sort
                        }) {
                            Label(sort.rawValue, systemImage: sort.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.selectedSort.iconName)
                            .font(.system(size: 12))
                        Text(viewModel.selectedSort.rawValue)
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
        .padding(.top, 6)
    }

    // MARK: - Selection Action Bar
    private var selectionActionBar: some View {
        HStack {
            Text("\(viewModel.selectedItemIds.count) marked (\(viewModel.formattedSelectedSize))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                viewModel.showDeleteConfirmation = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                    Text("Delete")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.red)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Media Found")
                .font(.system(size: 18, weight: .bold))
            Text("No photos or videos match this filter.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}
