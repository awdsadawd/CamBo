import SwiftUI
import Combine
import Photos
import UIKit

/// Controls overlay visibility in a 3-state cycle:
///  1. allVisible — photo overlay + UI all shown (brackets depend on lock)
///  2. photoHidden — reference image hidden so you can see your drawing, toolbar still visible
///  3. allHidden — fully immersive camera view, no toolbar, no overlay. Tap anywhere to restore.
public enum OverlayVisibility: Int, CaseIterable {
    case allVisible = 0
    case photoHidden = 1
    case allHidden = 2

    public var next: OverlayVisibility {
        let nextRaw = (self.rawValue + 1) % OverlayVisibility.allCases.count
        return OverlayVisibility(rawValue: nextRaw) ?? .allVisible
    }

    public var hideButtonIcon: String {
        switch self {
        case .allVisible:
            return "eye.slash"
        case .photoHidden:
            return "eye.slash.circle"
        case .allHidden:
            return "eye"
        }
    }

    public var hideButtonLabel: String {
        switch self {
        case .allVisible:
            return "Hide Photo"
        case .photoHidden:
            return "Hide All"
        case .allHidden:
            return "Show All"
        }
    }
}

/// State snapshot for undo/redo within the Trace session.
public struct TraceStateSnapshot: Equatable {
    public var offset: CGSize
    public var scale: CGFloat
    public var rotation: Angle
    public var opacity: Double
    public var isFlipped: Bool
}

/// Core ViewModel managing the tracing overlay, camera controls, filters, gestures, and composite export.
@MainActor
public final class TraceViewModel: ObservableObject {
    @Published public var sourceCroppedImage: UIImage
    public let mode: DrawingMode
    public var existingProjectId: UUID?

    // Overlay visual transform
    @Published public var offset: CGSize = .zero
    @Published public var scale: CGFloat = 1.0
    @Published public var rotation: Angle = .zero
    @Published public var opacity: Double = 0.5
    @Published public var isFlipped: Bool = false

    // Lock prevents gesture interaction AND hides corner brackets (image stays visible)
    @Published public var isLocked: Bool = false

    // 3-state visibility
    @Published public var visibility: OverlayVisibility = .allVisible

    public var isOverlayVisible: Bool { visibility == .allVisible }
    public var isUIVisible: Bool { visibility != .allHidden }

    // Filter
    @Published public var selectedFilter: TraceFilter = .original {
        didSet { updateFilteredImage() }
    }
    @Published public var displayFilteredImage: UIImage

    // Camera controls
    @Published public var isTorchOn: Bool = false

    // UI overlays & sheets
    @Published public var showOpacitySlider: Bool = false
    @Published public var showFilterSheet: Bool = false
    @Published public var showInfoTips: Bool = false
    @Published public var showFinishExport: Bool = false
    @Published public var showExitConfirmation: Bool = false
    @Published public var showRecropSheet: Bool = false
    @Published public var toastMessage: String? = nil

    // Drawing session timer
    @Published public var sessionStartTime: Date = Date()
    @Published public var sessionElapsed: TimeInterval = 0
    private var timerTask: Task<Void, Never>?

    // Composite export state
    @Published public var compositeImage: UIImage? = nil
    @Published public var isSavingPhoto: Bool = false

    // Screen mode brightness
    private var previousBrightness: CGFloat = 0.5

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

        if let state = initialState {
            self.offset = state.offset
            self.scale = state.scale
            self.rotation = state.rotation
            self.opacity = state.opacity
            self.isFlipped = state.isFlipped
            self.isLocked = state.isLocked
            self.selectedFilter = state.filter
            self.visibility = .allVisible
        } else {
            self.opacity = AppSettings.shared.defaultOpacity
        }

        updateFilteredImage()
    }

    // MARK: - Lifecycle

    public func onAppear() {
        // ★ CRITICAL: Prevent screen from auto-locking during tracing
        UIApplication.shared.isIdleTimerDisabled = true

        sessionStartTime = Date()
        startSessionTimer()

        if mode == .camera {
            cameraService.checkAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if let defaultPreset = self.cameraService.zoomPresets.first(where: { $0.label == "1.0x" }) {
                    self.cameraService.applyZoomPreset(defaultPreset)
                }
            }
        } else {
            // Screen mode: max brightness for tracing through paper
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
    }

    public func onDisappear() {
        // ★ Restore idle timer so screen can lock normally
        UIApplication.shared.isIdleTimerDisabled = false

        stopSessionTimer()

        if mode == .camera {
            cameraService.stopSession()
        } else {
            UIScreen.main.brightness = previousBrightness
        }

        autoSaveToRecent()
    }

    // MARK: - Session Timer

    private func startSessionTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self = self, !Task.isCancelled else { return }
                self.sessionElapsed = Date().timeIntervalSince(self.sessionStartTime)
            }
        }
    }

    private func stopSessionTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    public var formattedElapsed: String {
        let minutes = Int(sessionElapsed) / 60
        let seconds = Int(sessionElapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Transform & Gesture Controls

    public func recordHistory() {
        let snapshot = TraceStateSnapshot(
            offset: offset, scale: scale, rotation: rotation, opacity: opacity, isFlipped: isFlipped
        )
        undoStack.append(snapshot)
        redoStack.removeAll()
        updateUndoRedoStatus()
    }

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(TraceStateSnapshot(offset: offset, scale: scale, rotation: rotation, opacity: opacity, isFlipped: isFlipped))
        applySnapshot(previous)
        updateUndoRedoStatus()
        HapticService.shared.impact(.light)
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(TraceStateSnapshot(offset: offset, scale: scale, rotation: rotation, opacity: opacity, isFlipped: isFlipped))
        applySnapshot(next)
        updateUndoRedoStatus()
        HapticService.shared.impact(.light)
    }

    private func applySnapshot(_ s: TraceStateSnapshot) {
        offset = s.offset; scale = s.scale; rotation = s.rotation; opacity = s.opacity; isFlipped = s.isFlipped
    }

    private func updateUndoRedoStatus() {
        canUndo = !undoStack.isEmpty; canRedo = !redoStack.isEmpty
    }

    /// Lock: prevents drag/pinch/rotate AND hides corner brackets. Image stays visible.
    public func toggleLock() {
        isLocked.toggle()
        HapticService.shared.impact(.medium)
        showToast(isLocked ? "🔒 Locked — Brackets Hidden" : "🔓 Unlocked")
    }

    public func toggleFlip() {
        recordHistory()
        withAnimation(.easeInOut(duration: 0.25)) { isFlipped.toggle() }
        HapticService.shared.impact(.light)
    }

    /// Cycle: allVisible → photoHidden → allHidden → allVisible
    public func cycleVisibility() {
        withAnimation(.easeInOut(duration: 0.2)) { visibility = visibility.next }
        HapticService.shared.impact(.light)
        switch visibility {
        case .allVisible: showToast("Everything Visible")
        case .photoHidden: showToast("Photo Hidden — Check Your Drawing")
        case .allHidden: showToast("Immersive Mode — Tap to Restore")
        }
    }

    public func toggleTorch() {
        cameraService.toggleTorch()
        isTorchOn = cameraService.isTorchOn
        HapticService.shared.impact(.light)
    }

    public func selectZoomPreset(_ preset: CameraZoomPreset) {
        cameraService.applyZoomPreset(preset)
        HapticService.shared.selection()
    }

    public func resetTransform() {
        recordHistory()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            offset = .zero; scale = 1.0; rotation = .zero
            opacity = AppSettings.shared.defaultOpacity
            isFlipped = false; visibility = .allVisible; isLocked = false
        }
        HapticService.shared.impact(.medium)
        showToast("Reset to Default")
    }

    // MARK: - Re-crop

    public func updateSourceImage(_ newImage: UIImage) {
        sourceCroppedImage = newImage
        updateFilteredImage()
        HapticService.shared.notification(.success)
        showToast("Image Re-cropped ✂️")
    }

    // MARK: - Filters

    private func updateFilteredImage() {
        displayFilteredImage = filterService.applyFilter(selectedFilter, to: sourceCroppedImage)
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
            isHidden: false,
            filter: selectedFilter,
            guideType: .none
        )

        _ = historyStore.saveProject(
            image: sourceCroppedImage,
            mode: mode,
            overlayState: currentState,
            existingId: existingProjectId,
            sessionDuration: sessionElapsed
        )
    }

    // MARK: - Composite & Save

    public func prepareFinish() async {
        isSavingPhoto = true
        autoSaveToRecent()

        var bg: UIImage? = nil
        if mode == .camera { bg = await cameraService.capturePhoto() }

        compositeImage = renderComposite(background: bg)
        isSavingPhoto = false
        showFinishExport = true
    }

    public func renderComposite(background: UIImage?) -> UIImage {
        let targetSize = background?.size ?? CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            if let bg = background {
                bg.draw(in: CGRect(origin: .zero, size: targetSize))
            } else {
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: targetSize))
            }
            if visibility == .allVisible && opacity > 0.01 {
                let context = ctx.cgContext
                context.saveGState()
                let center = CGPoint(x: targetSize.width / 2 + offset.width, y: targetSize.height / 2 + offset.height)
                context.translateBy(x: center.x, y: center.y)
                context.rotate(by: CGFloat(rotation.radians))
                if isFlipped { context.scaleBy(x: -1, y: 1) }
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
                    continuation.resume(returning: false); return
                }
                UIImageWriteToSavedPhotosAlbum(composite, nil, nil, nil)
                HapticService.shared.notification(.success)
                continuation.resume(returning: true)
            }
        }
    }

    public func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toastMessage == message { toastMessage = nil }
        }
    }
}
