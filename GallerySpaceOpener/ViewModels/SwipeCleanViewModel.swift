import SwiftUI
import Photos
import Combine

public enum SwipeAction: Equatable, Sendable {
    case delete // Swiped Right
    case keep   // Swiped Left
}

public struct SwipeHistoryItem: Identifiable, Equatable, Sendable {
    public var id: String { item.id }
    public let item: MediaItem
    public let action: SwipeAction

    public init(item: MediaItem, action: SwipeAction) {
        self.item = item
        self.action = action
    }
}

/// ViewModel powering the Tinder-like card swiper for rapidly cleaning gallery storage.
@MainActor
public final class SwipeCleanViewModel: ObservableObject {
    @Published public var deckItems: [MediaItem] = []
    @Published public var swipedDeletedItems: [MediaItem] = []
    @Published public var swipedKeptItems: [MediaItem] = []
    @Published public var undoHistory: [SwipeHistoryItem] = []

    @Published public var isPreparingDeck: Bool = false
    @Published public var showReviewScreen: Bool = false
    @Published public var isDeletingBatch: Bool = false
    @Published public var toastMessage: String? = nil

    // Drag gesture tracking for the topmost card
    @Published public var dragOffset: CGSize = .zero
    @Published public var cardRotation: Angle = .zero
    /// True while a card is flying off-screen; blocks double swipes.
    @Published public private(set) var isSwiping: Bool = false

    private let libraryManager = PhotoLibraryManager.shared
    private let settings = AppSettings.shared

    public init() {
        Task {
            await prepareDeck()
        }
    }

    public var currentCard: MediaItem? {
        deckItems.first
    }

    public var nextCard: MediaItem? {
        deckItems.count > 1 ? deckItems[1] : nil
    }

    public var deletedBytesTotal: Int64 {
        swipedDeletedItems.reduce(0) { $0 + $1.fileSizeBytes }
    }

    public var formattedDeletedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: deletedBytesTotal)
    }

    public var canUndo: Bool {
        !undoHistory.isEmpty
    }

    /// Loads items into the Tinder swipe deck, prioritizing largest files first to maximize reclaimed space.
    public func prepareDeck(filter: MediaFilterType = .all) async {
        isPreparingDeck = true
        let items = await libraryManager.fetchMediaItems(filter: filter, sort: .sizeDesc)
        self.deckItems = items
        self.swipedDeletedItems = []
        self.swipedKeptItems = []
        self.undoHistory = []
        self.dragOffset = .zero
        self.cardRotation = .zero
        self.isSwiping = false
        self.isPreparingDeck = false
    }

    // MARK: - Gestures & Actions

    /// Swipe RIGHT -> Mark for DELETE
    public func swipeRightDelete() {
        performSwipe(.delete)
    }

    /// Swipe LEFT -> KEEP
    public func swipeLeftKeep() {
        performSwipe(.keep)
    }

    private func performSwipe(_ action: SwipeAction) {
        // Lock: ignore extra taps / drags while the fly-out animation is running
        guard !isSwiping, let item = deckItems.first else { return }
        isSwiping = true

        if settings.hapticsEnabled {
            if action == .delete {
                HapticManager.shared.swipeDelete()
            } else {
                HapticManager.shared.swipeKeep()
            }
        }

        let direction: CGFloat = (action == .delete) ? 1 : -1
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: 650 * direction, height: 40)
            cardRotation = Angle(degrees: 18 * Double(direction))
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 230_000_000)

            // Remove exactly the card that was swiped
            if let index = self.deckItems.firstIndex(where: { $0.id == item.id }) {
                self.deckItems.remove(at: index)
            }
            item.isMarkedForDeletion = (action == .delete)
            if action == .delete {
                self.swipedDeletedItems.append(item)
            } else {
                self.swipedKeptItems.append(item)
            }
            self.undoHistory.append(SwipeHistoryItem(item: item, action: action))

            // Reset without animation so the next card appears centered instantly
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.resetCardOffset()
            }
            self.isSwiping = false

            if self.deckItems.isEmpty {
                self.showReviewScreen = true
            }
        }
    }

    /// Reverts the most recent swipe action.
    public func undoLastSwipe() {
        guard !isSwiping, let last = undoHistory.popLast() else { return }

        if settings.hapticsEnabled {
            HapticManager.shared.undo()
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            switch last.action {
            case .delete:
                swipedDeletedItems.removeAll { $0.id == last.item.id }
            case .keep:
                swipedKeptItems.removeAll { $0.id == last.item.id }
            }
            deckItems.insert(last.item, at: 0)
            resetCardOffset()
        }
    }

    public func resetCardOffset() {
        dragOffset = .zero
        cardRotation = .zero
    }

    public func finishSession() {
        showReviewScreen = true
    }

    // MARK: - Review Screen Item Management

    /// Manually remove an item from the delete list and keep it.
    public func keepItemManually(item: MediaItem) {
        swipedDeletedItems.removeAll { $0.id == item.id }
        swipedKeptItems.append(item)
        if settings.hapticsEnabled {
            HapticManager.shared.selection()
        }
    }

    /// Permanently deletes all items in swipedDeletedItems via PHPhotoLibrary.
    public func confirmDeleteAll() async -> Bool {
        guard !swipedDeletedItems.isEmpty else { return true }

        isDeletingBatch = true
        let itemsToDelete = swipedDeletedItems
        let result = await libraryManager.deleteAssets(itemsToDelete)
        isDeletingBatch = false

        switch result {
        case .success(let count):
            let freedBytes = itemsToDelete.reduce(0) { $0 + $1.fileSizeBytes }
            settings.recordClean(bytes: freedBytes, count: count)
            showToast("Freed \(ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file))! 🗑️")
            swipedDeletedItems.removeAll()
            return true
        case .failure(let error):
            showToast("Error: \(error.localizedDescription)")
            return false
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
