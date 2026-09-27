import SwiftUI
import Combine
import Photos

/// State snapshot for undo/redo within the Trace session.
public struct TraceStateSnapshot: Equatable {
    public var offset: CGSize
    public var scale: CGFloat
    public var rotation: Angle
    public var opacity: Double
    public var isFlipped: Bool
}

/// Core ViewModel managing the tracing overlay, camera controls, filters, guides, gestures, and composite export.
@MainActor
public final class TraceViewModel: ObservableObject {
    public let sourceCroppedImage: UIImage
    public let mode: DrawingMode
    public var existingProjectId: UUID?

    // Overlay visual transform
    @Published public var offset: CGSize = .zero
    @Published public var scale: CGFloat = 1.0
    @Published public var rotation: Angle = .zero
    @Published public var opacity: Double = 0.5
    @Published public var isFlipped: Bool = false
    @Published public var isLocked: Bool = false
    @Published public var isHidden: Bool = false

    // Filter & Guide
    @Published public var selectedFilter: TraceFilter = .original {
        didSet {
            updateFilteredImage()
        }
    }
    @Published public var displayFilteredImage: UIImage
    @Published public var guideType: GuideOverlayType = .none

    // Camera controls
    @Published public var selectedCameraZoom: CGFloat = 1.0
    @Published public var isTorchOn: Bool = false

    // UI overlays & sheets
    @Published public var showOpacitySlider: Bool = false
    @Published public var showFilterSheet: Bool = false
    @Published public var showGuideSheet: Bool = false
    @Published public var showInfoTips: Bool = false
    @Published public var showFinishExport: Bool = false
    @Published public var showExitConfirmation: Bool = false
    @Published public var toastMessage: String? = nil

    // Composite export state
    @Published public var compositeImage: UIImage? = nil
    @Published public var isSavingPhoto: Bool = false

    // Undo / Redo history
    private var undoStack: [TraceStateSnapshot] = []
    private var redoStack: [TraceStateSnapshot] = []
    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false

    public let cameraService = CameraService.shared
    private let historyStore = ProjectHistoryStore.shared
    private let filterService = ImageFilterService.shared

    public init(
        image: UIImage,
        mode: DrawingMode = .camera,
        initialState: TraceOverlayState? = nil,
        existingProjectId: UUID? = nil
    ) {
        self.sourceCroppedImage = image
        self.displayFilteredImage = image
        self.mode = mode
        self.existingProjectId = existingProjectId

        let defaultOpacity = AppSettings.shared.defaultOpacity
        let defaultZoom = AppSettings.shared.defaultZoom
        let defaultGuide = AppSettings.shared.defaultGuideType

        if let state = initialState {
            self.offset = state.offset
            self.scale = state.scale
            self.rotation = state.rotation
            self.opacity = state.opacity
            self.isFlipped = state.isFlipped
            self.isLocked = state.isLocked
            self.isHidden = state.isHidden
            self.selectedFilter = state.filter
            self.guideType = state.guideType
        } else {
            self.opacity = defaultOpacity
            self.selectedCameraZoom = defaultZoom
            self.guideType = defaultGuide
        }

        updateFilteredImage()
    }

    public func onAppear() {
        if mode == .camera {
            cameraService.startSession()
            cameraService.setZoom(selectedCameraZoom)
        }
    }

    public func onDisappear() {
        if mode == .camera {
            cameraService.stopSession()
        }
        autoSaveToRecent()
    }

    // MARK: - Transform & Gesture Controls

    public func recordHistory() {
        let snapshot = TraceStateSnapshot(
            offset: offset,
            scale: scale,
            rotation: rotation,
            opacity: opacity,
            isFlipped: isFlipped
        )
        undoStack.append(snapshot)
        redoStack.removeAll()
        updateUndoRedoStatus()
    }

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        let current = TraceStateSnapshot(
            offset: offset,
            scale: scale,
            rotation: rotation,
            opacity: opacity,
            isFlipped: isFlipped
        )
        redoStack.append(current)
        applySnapshot(previous)
        updateUndoRedoStatus()
        HapticService.shared.impact(.light)
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        let current = TraceStateSnapshot(
            offset: offset,
            scale: scale,
            rotation: rotation,
            opacity: opacity,
            isFlipped: isFlipped
        )
        undoStack.append(current)
        applySnapshot(next)
        updateUndoRedoStatus()
        HapticService.shared.impact(.light)
    }

    private func applySnapshot(_ snapshot: TraceStateSnapshot) {
        self.offset = snapshot.offset
        self.scale = snapshot.scale
        self.rotation = snapshot.rotation
        self.opacity = snapshot.opacity
        self.isFlipped = snapshot.isFlipped
    }

    private func updateUndoRedoStatus() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    public func toggleLock() {
        isLocked.toggle()
        HapticService.shared.impact(.medium)
        showToast(isLocked ? "Overlay Locked" : "Overlay Unlocked")
    }

    public func toggleFlip() {
        recordHistory()
        withAnimation(.easeInOut(duration: 0.25)) {
            isFlipped.toggle()
        }
        HapticService.shared.impact(.light)
    }

    public func toggleHidden() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isHidden.toggle()
        }
        HapticService.shared.impact(.light)
    }

    public func toggleTorch() {
        cameraService.toggleTorch()
        isTorchOn = cameraService.isTorchOn
        HapticService.shared.impact(.light)
    }

    public func setCameraZoom(_ factor: CGFloat) {
        selectedCameraZoom = factor
        cameraService.setZoom(factor)
        HapticService.shared.selection()
    }

    public func resetTransform() {
        recordHistory()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            offset = .zero
            scale = 1.0
            rotation = .zero
            opacity = AppSettings.shared.defaultOpacity
            isFlipped = false
            isHidden = false
        }
        HapticService.shared.impact(.medium)
        showToast("Reset to Default")
    }

    // MARK: - Filters

    private func updateFilteredImage() {
        self.displayFilteredImage = filterService.applyFilter(selectedFilter, to: sourceCroppedImage)
    }

    // MARK: - Project Persistence

    public func autoSaveToRecent() {
        let currentState = TraceOverlayState(
            offsetWidth: Double(offset.width),
            offsetHeight: Double(offset.height),
            scale: Double(scale),
            rotationDegrees: rotation.degrees,
            opacity: opacity,
            isFlipped: isFlipped,
            isLocked: isLocked,
            isHidden: isHidden,
            filter: selectedFilter,
            guideType: guideType
        )

        _ = historyStore.saveProject(
            image: sourceCroppedImage,
            mode: mode,
            overlayState: currentState,
            existingId: existingProjectId
        )
    }

    // MARK: - Composite Generation & Photo Saving

    public func prepareFinish() async {
        isSavingPhoto = true
        autoSaveToRecent()

        var baseBackground: UIImage? = nil
        if mode == .camera {
            baseBackground = await cameraService.capturePhoto()
        }

        // Render composite
        let composite = renderComposite(background: baseBackground)
        self.compositeImage = composite
        self.isSavingPhoto = false
        self.showFinishExport = true
    }

    public func renderComposite(background: UIImage?) -> UIImage {
        let targetSize = background?.size ?? CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { ctx in
            // Background
            if let bg = background {
                bg.draw(in: CGRect(origin: .zero, size: targetSize))
            } else {
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: targetSize))
            }

            // Burn overlay if not hidden
            if !isHidden && opacity > 0.01 {
                let context = ctx.cgContext
                context.saveGState()

                let center = CGPoint(x: targetSize.width / 2 + offset.width, y: targetSize.height / 2 + offset.height)
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: CGFloat(rotation.radians))
                if isFlipped {
                    context.scaleBy(x: -1, y: 1)
                }

                let overlayWidth = targetSize.width * 0.75 * scale
                let aspect = displayFilteredImage.size.height / displayFilteredImage.size.width
                let overlayHeight = overlayWidth * aspect
                let rect = CGRect(x: -overlayWidth / 2, y: -overlayHeight / 2, width: overlayWidth, height: overlayHeight)

                context.setAlpha(CGFloat(opacity))
                displayFilteredImage.draw(in: rect)
                context.restoreGState()
            }
        }
    }

    public func saveCompositeToPhotos() async -> Bool {
        guard let composite = compositeImage else { return false }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    continuation.resume(returning: false)
                    return
                }

                UIImageWriteToSavedPhotosAlbum(composite, nil, nil, nil)
                HapticService.shared.notification(.success)
                continuation.resume(returning: true)
            }
        }
    }

    public func showToast(_ message: String) {
        self.toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
}
