import SwiftUI
import Photos
import Combine

/// Main ViewModel driving the gallery explorer, filtering, sorting, and manual selections.
@MainActor
public final class GalleryViewModel: ObservableObject {
    @Published public var items: [MediaItem] = []
    @Published public var selectedFilter: MediaFilterType = .all {
        didSet { Task { await reloadMedia() } }
    }
    @Published public var selectedSort: MediaSortOption = .sizeDesc {
        didSet { applySort() }
    }

    @Published public var selectedItemIds: Set<String> = []
    @Published public var activeDetailItem: MediaItem? = nil
    @Published public var showDetailModal: Bool = false
    @Published public var showDeleteConfirmation: Bool = false
    @Published public var isDeleting: Bool = false
    @Published public var toastMessage: String? = nil

    private let libraryManager = PhotoLibraryManager.shared
    private let settings = AppSettings.shared

    public init() {
        Task {
            await reloadMedia()
        }
    }

    public var totalLibraryBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSizeBytes }
    }

    public var formattedTotalLibrarySize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalLibraryBytes)
    }

    public var selectedBytes: Int64 {
        items
            .filter { selectedItemIds.contains($0.id) }
            .reduce(0) { $0 + $1.fileSizeBytes }
    }

    public var formattedSelectedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: selectedBytes)
    }

    public var isSelectionMode: Bool {
        !selectedItemIds.isEmpty
    }

    public func reloadMedia(forceRefresh: Bool = false) async {
        let requestedFilter = selectedFilter
        let fetched = await libraryManager.fetchMediaItems(
            filter: requestedFilter,
            sort: selectedSort,
            forceRefresh: forceRefresh
        )
        // Drop stale results if the user switched filters while we were loading
        guard requestedFilter == selectedFilter else { return }
        self.items = libraryManager.sortItems(fetched, by: selectedSort)
        self.selectedItemIds.removeAll()
    }

    public func applySort() {
        self.items = libraryManager.sortItems(items, by: selectedSort)
    }

    public func toggleSelection(for item: MediaItem) {
        if selectedItemIds.contains(item.id) {
            selectedItemIds.remove(item.id)
        } else {
            selectedItemIds.insert(item.id)
            if settings.hapticsEnabled {
                HapticManager.shared.selection()
            }
        }
    }

    public func selectAll() {
        selectedItemIds = Set(items.map { $0.id })
    }

    public func clearSelection() {
        selectedItemIds.removeAll()
    }

    public func openDetail(for item: MediaItem) {
        self.activeDetailItem = item
        self.showDetailModal = true
    }

    public func deleteSelectedItems() async {
        let itemsToDelete = items.filter { selectedItemIds.contains($0.id) }
        guard !itemsToDelete.isEmpty else { return }

        isDeleting = true
        let result = await libraryManager.deleteAssets(itemsToDelete)
        isDeleting = false

        switch result {
        case .success(let count):
            let freedBytes = itemsToDelete.reduce(0) { $0 + $1.fileSizeBytes }
            settings.recordClean(bytes: freedBytes, count: count)
            showToast("Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))! 🚀")
            await reloadMedia()
        case .failure(let error):
            showToast("Error: \(error.localizedDescription)")
        }
    }

    public func deleteSingleItem(_ item: MediaItem) async {
        isDeleting = true
        let result = await libraryManager.deleteAssets([item])
        isDeleting = false

        switch result {
        case .success:
            settings.recordClean(bytes: item.fileSizeBytes, count: 1)
            showToast("Deleted \(item.formattedFileSize)")
            await reloadMedia()
        case .failure(let error):
            showToast("Error: \(error.localizedDescription)")
        }
    }

    public func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
