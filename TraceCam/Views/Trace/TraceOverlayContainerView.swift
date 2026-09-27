import SwiftUI

/// Container for the floating reference image overlay with interactive drag, pinch, and rotate gestures.
/// Corner brackets always render when the overlay is visible, regardless of lock state.
/// Lock only disables gesture interaction.
public struct TraceOverlayContainerView: View {
    @ObservedObject var viewModel: TraceViewModel

    // Gesture state tracking — stored independently so cumulative translation doesn't compound
    @State private var dragOffset: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0
    @State private var rotationDelta: Angle = .zero

    public init(viewModel: TraceViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { geo in
            let baseWidth = min(geo.size.width * 0.78, 480)
            let aspect = viewModel.displayFilteredImage.size.height / max(viewModel.displayFilteredImage.size.width, 1)
            let baseHeight = baseWidth * aspect

            ZStack {
                // The Reference Image with Corner Brackets
                // Visible ONLY in .allVisible state; hidden in .photoHidden and .allHidden
                if viewModel.visibility == .allVisible {
                    ZStack {
                        Image(uiImage: viewModel.displayFilteredImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(x: viewModel.isFlipped ? -1 : 1, y: 1)
                            .opacity(viewModel.opacity)

                        // Signature Violet Corner Brackets — always visible when overlay is shown
                        // Lock does NOT hide these; only the Hide button does.
                        CornerBracketsView(cornerLength: 32, lineWidth: 4.5)
                    }
                    .frame(width: baseWidth, height: baseHeight)
                    // Visual transformations
                    .scaleEffect(viewModel.scale * pinchScale)
                    .rotationEffect(viewModel.rotation + rotationDelta)
                    .offset(
                        x: viewModel.offset.width + dragOffset.width,
                        y: viewModel.offset.height + dragOffset.height
                    )
                    // Gestures (disabled when locked — but image + brackets still display)
                    .gesture(
                        viewModel.isLocked ? nil : makeCombinedGestures()
                    )
                    .transition(.opacity)
                }

                // Guide Grid Overlay (always shown when enabled, even if photo is hidden)
                if viewModel.guideType != .none {
                    GuideGridView(type: viewModel.guideType)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func makeCombinedGestures() -> some Gesture {
        let dragGesture = DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                viewModel.recordHistory()
                viewModel.offset.width += value.translation.width
                viewModel.offset.height += value.translation.height
                dragOffset = .zero
            }

        let magnificationGesture = MagnificationGesture()
            .onChanged { value in
                pinchScale = value
            }
            .onEnded { value in
                viewModel.recordHistory()
                viewModel.scale = max(0.2, min(viewModel.scale * value, 6.0))
                pinchScale = 1.0
            }

        let rotationGesture = RotationGesture()
            .onChanged { value in
                rotationDelta = value
            }
            .onEnded { value in
                viewModel.recordHistory()
                viewModel.rotation += value
                rotationDelta = .zero
            }

        return dragGesture
            .simultaneously(with: magnificationGesture)
            .simultaneously(with: rotationGesture)
    }
}
