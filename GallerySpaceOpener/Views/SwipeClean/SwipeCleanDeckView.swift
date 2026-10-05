import SwiftUI

/// Main Tinder-like swiping deck where users swipe right to delete and left to keep.
public struct SwipeCleanDeckView: View {
    @ObservedObject var viewModel: SwipeCleanViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: SwipeCleanViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if viewModel.isPreparingDeck {
                    loadingDeckView
                } else if viewModel.deckItems.isEmpty {
                    allCleanFinishedView
                } else {
                    VStack(spacing: 12) {
                        // Top Stats & Progress Bar
                        statsProgressBar

                        // Tinder Card Stack
                        cardStackView
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        // Bottom Controls (Keep, Undo, Delete)
                        SwipeControlsBar(
                            canUndo: viewModel.canUndo,
                            onKeep: { viewModel.swipeLeftKeep() },
                            onUndo: { viewModel.undoLastSwipe() },
                            onDelete: { viewModel.swipeRightDelete() }
                        )
                        .padding(.bottom, 10)
                    }
                }
            }
            .navigationTitle("Tinder Clean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.finishSession()
                    }) {
                        HStack(spacing: 4) {
                            Text("Done")
                                .font(.system(size: 15, weight: .bold))
                            if !viewModel.swipedDeletedItems.isEmpty {
                                Text("(\(viewModel.swipedDeletedItems.count))")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showReviewScreen) {
                DeletionReviewView(viewModel: viewModel) {
                    // On finished deletions, prepare deck again or dismiss
                    Task { await viewModel.prepareDeck() }
                }
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

    // MARK: - Stats Progress Bar
    private var statsProgressBar: some View {
        HStack {
            // Cards Remaining
            HStack(spacing: 5) {
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 11))
                Text("\(viewModel.deckItems.count) Left")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color(.secondarySystemBackground)))

            Spacer()

            // Space to Reclaim
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                Text("\(viewModel.formattedDeletedSize) Marked")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.red.opacity(0.12)))
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Card Stack View
    private var cardStackView: some View {
        ZStack {
            // Background Next Card
            if let nextItem = viewModel.nextCard {
                SwipeCardView(item: nextItem)
                    .scaleEffect(0.95)
                    .offset(y: 12)
                    .allowsHitTesting(false)
            }

            // Foreground Top Card with Interactive Drag Gesture
            if let currentItem = viewModel.currentCard {
                SwipeCardView(item: currentItem, dragOffset: viewModel.dragOffset)
                    .offset(viewModel.dragOffset)
                    .rotationEffect(viewModel.cardRotation)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                viewModel.dragOffset = gesture.translation
                                viewModel.cardRotation = Angle(degrees: Double(gesture.translation.width / 22.0))
                            }
                            .onEnded { gesture in
                                let threshold: CGFloat = 120
                                if gesture.translation.width > threshold {
                                    // Swipe Right -> DELETE
                                    viewModel.swipeRightDelete()
                                } else if gesture.translation.width < -threshold {
                                    // Swipe Left -> KEEP
                                    viewModel.swipeLeftKeep()
                                } else {
                                    // Snap back
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        viewModel.resetCardOffset()
                                    }
                                }
                            }
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading Deck View
    private var loadingDeckView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text("Scanning & sorting largest media...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - All Clean Finished View
    private var allCleanFinishedView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 90, height: 90)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
            }

            Text("All Caught Up!")
                .font(.system(size: 24, weight: .heavy))

            Text("You've reviewed all items in this section.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !viewModel.swipedDeletedItems.isEmpty {
                Button(action: {
                    viewModel.showReviewScreen = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text("Review Marked Deletions (\(viewModel.formattedDeletedSize))")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
                .padding(.top, 10)
            }

            Button("Return to Gallery") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.top, 6)
        }
        .padding(32)
    }
}
