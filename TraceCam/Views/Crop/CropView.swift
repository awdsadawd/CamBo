import SwiftUI

/// Screen 2: Dedicated image cropping interface with freeform 4-corner handles, 90° rotation, zoom, and undo/redo.
/// FIXED: Drag gestures now track the initial position at gesture start, preventing exponential fling.
public struct CropView: View {
    public let originalImage: UIImage
    public let existingProjectId: UUID?
    public let onReturnHome: () -> Void

    @StateObject private var viewModel: CropViewModel
    @State private var croppedImageResult: UIImage? = nil
    @State private var navigateToModePicker: Bool = false

    public init(originalImage: UIImage, existingProjectId: UUID? = nil, onReturnHome: @escaping () -> Void) {
        self.originalImage = originalImage
        self.existingProjectId = existingProjectId
        self.onReturnHome = onReturnHome
        _viewModel = StateObject(wrappedValue: CropViewModel(sourceImage: originalImage))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar: Undo, Redo, Rotate 90°, Reset
            HStack {
                HStack(spacing: 12) {
                    Button(action: { viewModel.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(!viewModel.canUndo)

                    Button(action: { viewModel.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(!viewModel.canRedo)
                }
                .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 16) {
                    // Rotate 90°
                    Button(action: {
                        viewModel.rotate90()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "rotate.right")
                            Text("Rotate")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }

                    // Reset
                    Button(action: {
                        viewModel.reset()
                    }) {
                        Text("Reset")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Crop Canvas Area
            GeometryReader { geo in
                let canvasWidth = geo.size.width
                let canvasHeight = geo.size.height

                ZStack {
                    Color.black.opacity(0.92)

                    // Source Image (Rotated & Zoomed)
                    Image(uiImage: viewModel.sourceImage)
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(.degrees(Double(viewModel.rotationDegrees)))
                        .scaleEffect(viewModel.zoomScale)
                        .frame(width: canvasWidth, height: canvasHeight)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    viewModel.zoomScale = max(0.5, min(value, 4.0))
                                }
                        )

                    // 4-Corner Draggable Crop Overlay — FIXED gestures
                    StableCropBoxView(
                        cropRect: $viewModel.cropRect,
                        containerSize: CGSize(width: canvasWidth, height: canvasHeight),
                        onCommit: {
                            viewModel.recordHistory()
                        }
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)

            // Bottom Continue Button
            VStack(spacing: 8) {
                Button(action: {
                    HapticService.shared.impact(.medium)
                    let cropped = viewModel.produceCroppedImage()
                    self.croppedImageResult = cropped
                    self.navigateToModePicker = true
                }) {
                    Text("Confirm Crop & Continue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(red: 0.54, green: 0.28, blue: 0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Crop & Align")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToModePicker) {
            if let cropped = croppedImageResult {
                ModePickerView(
                    croppedImage: cropped,
                    existingProjectId: existingProjectId,
                    onReturnHome: onReturnHome
                )
            }
        }
    }
}

// MARK: - StableCropBoxView (FIXED gesture tracking)

/// Interactive Crop Box with proper gesture start-state tracking.
/// The previous version applied `DragGesture.translation` (which is cumulative from gesture start)
/// as a per-frame delta, causing exponential fly-off. This version captures the rect at gesture
/// start and computes position = startRect + normalizedTranslation.
struct StableCropBoxView: View {
    @Binding var cropRect: CGRect // Normalized 0...1
    let containerSize: CGSize
    let onCommit: () -> Void

    private let handleSize: CGFloat = 32
    private let violetColor = Color(red: 0.54, green: 0.28, blue: 0.98)

    // Track starting position when each gesture begins
    @State private var boxDragStart: CGRect? = nil
    @State private var cornerDragStart: CGRect? = nil

    var body: some View {
        let pixelRect = CGRect(
            x: cropRect.origin.x * containerSize.width,
            y: cropRect.origin.y * containerSize.height,
            width: cropRect.size.width * containerSize.width,
            height: cropRect.size.height * containerSize.height
        )

        ZStack {
            // Dimmed mask outside crop area
            DimmedCropMask(innerRect: pixelRect, containerSize: containerSize)
                .allowsHitTesting(false)

            // Crop Box Border
            Rectangle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: pixelRect.width, height: pixelRect.height)
                .position(x: pixelRect.midX, y: pixelRect.midY)

            // Rule of thirds grid inside crop box
            CropInternalGrid(rect: pixelRect)
                .allowsHitTesting(false)

            // Drag whole box gesture
            Color.clear
                .frame(width: max(0, pixelRect.width - handleSize * 2), height: max(0, pixelRect.height - handleSize * 2))
                .position(x: pixelRect.midX, y: pixelRect.midY)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Capture initial rect on first frame of this gesture
                            if boxDragStart == nil {
                                boxDragStart = cropRect
                            }
                            guard let startRect = boxDragStart else { return }

                            let deltaX = value.translation.width / containerSize.width
                            let deltaY = value.translation.height / containerSize.height

                            var newX = startRect.origin.x + deltaX
                            var newY = startRect.origin.y + deltaY

                            // Clamp so box doesn't go off-canvas
                            newX = max(0, min(newX, 1.0 - startRect.width))
                            newY = max(0, min(newY, 1.0 - startRect.height))

                            cropRect = CGRect(x: newX, y: newY, width: startRect.width, height: startRect.height)
                        }
                        .onEnded { _ in
                            boxDragStart = nil
                            onCommit()
                        }
                )

            // 4 Corner Drag Handles
            cornerHandle(position: CGPoint(x: pixelRect.minX, y: pixelRect.minY), type: .topLeft)
            cornerHandle(position: CGPoint(x: pixelRect.maxX, y: pixelRect.minY), type: .topRight)
            cornerHandle(position: CGPoint(x: pixelRect.minX, y: pixelRect.maxY), type: .bottomLeft)
            cornerHandle(position: CGPoint(x: pixelRect.maxX, y: pixelRect.maxY), type: .bottomRight)
        }
    }

    enum CornerType { case topLeft, topRight, bottomLeft, bottomRight }

    private func cornerHandle(position: CGPoint, type: CornerType) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle().stroke(violetColor, lineWidth: 3.5)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 4)
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Capture initial rect on first frame
                        if cornerDragStart == nil {
                            cornerDragStart = cropRect
                        }
                        guard let startRect = cornerDragStart else { return }

                        updateCorner(type: type, startRect: startRect, translation: value.translation)
                    }
                    .onEnded { _ in
                        cornerDragStart = nil
                        onCommit()
                    }
            )
    }

    /// Computes new corner position from the STARTING rect + cumulative translation.
    /// This prevents the exponential fly-off from the previous implementation.
    private func updateCorner(type: CornerType, startRect: CGRect, translation: CGSize) {
        let minSize: CGFloat = 0.12 // Minimum 12% width/height
        let deltaX = translation.width / containerSize.width
        let deltaY = translation.height / containerSize.height

        var r: CGRect

        switch type {
        case .topLeft:
            let newX = max(0, min(startRect.maxX - minSize, startRect.minX + deltaX))
            let newY = max(0, min(startRect.maxY - minSize, startRect.minY + deltaY))
            r = CGRect(x: newX, y: newY, width: startRect.maxX - newX, height: startRect.maxY - newY)

        case .topRight:
            let newMaxX = max(startRect.minX + minSize, min(1.0, startRect.maxX + deltaX))
            let newY = max(0, min(startRect.maxY - minSize, startRect.minY + deltaY))
            r = CGRect(x: startRect.minX, y: newY, width: newMaxX - startRect.minX, height: startRect.maxY - newY)

        case .bottomLeft:
            let newX = max(0, min(startRect.maxX - minSize, startRect.minX + deltaX))
            let newMaxY = max(startRect.minY + minSize, min(1.0, startRect.maxY + deltaY))
            r = CGRect(x: newX, y: startRect.minY, width: startRect.maxX - newX, height: newMaxY - startRect.minY)

        case .bottomRight:
            let newMaxX = max(startRect.minX + minSize, min(1.0, startRect.maxX + deltaX))
            let newMaxY = max(startRect.minY + minSize, min(1.0, startRect.maxY + deltaY))
            r = CGRect(x: startRect.minX, y: startRect.minY, width: newMaxX - startRect.minX, height: newMaxY - startRect.minY)
        }

        self.cropRect = r
    }
}

/// Renders a dimmed shroud outside the crop rectangle.
struct DimmedCropMask: View {
    let innerRect: CGRect
    let containerSize: CGSize

    var body: some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: containerSize))
            path.addRect(innerRect)
        }
        .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
    }
}

/// Internal Rule of Thirds grid for the crop box.
struct CropInternalGrid: View {
    let rect: CGRect

    var body: some View {
        Path { path in
            let w = rect.width
            let h = rect.height
            let x = rect.minX
            let y = rect.minY

            // Verticals
            path.move(to: CGPoint(x: x + w / 3, y: y))
            path.addLine(to: CGPoint(x: x + w / 3, y: y + h))
            path.move(to: CGPoint(x: x + 2 * w / 3, y: y))
            path.addLine(to: CGPoint(x: x + 2 * w / 3, y: y + h))

            // Horizontals
            path.move(to: CGPoint(x: x, y: y + h / 3))
            path.addLine(to: CGPoint(x: x + w, y: y + h / 3))
            path.move(to: CGPoint(x: x, y: y + 2 * h / 3))
            path.addLine(to: CGPoint(x: x + w, y: y + 2 * h / 3))
        }
        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
        .allowsHitTesting(false)
    }
}
