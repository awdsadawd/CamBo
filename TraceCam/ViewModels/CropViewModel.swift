import SwiftUI
import Combine

/// State snapshot for undo/redo within the Crop session.
public struct CropStateSnapshot: Equatable {
    public var cropRect: CGRect // Normalized 0...1
    public var rotationDegrees: Int // 0, 90, 180, 270
}

/// ViewModel for interactive 4-corner cropping, rotating 90°, zooming, and undo/redo.
@MainActor
public final class CropViewModel: ObservableObject {
    public let sourceImage: UIImage

    // Normalized coordinates (0.0 to 1.0)
    @Published public var cropRect: CGRect = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
    @Published public var rotationDegrees: Int = 0 // 0, 90, 180, 270
    @Published public var zoomScale: CGFloat = 1.0

    // History for Undo / Redo
    private var undoStack: [CropStateSnapshot] = []
    private var redoStack: [CropStateSnapshot] = []

    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false

    public init(sourceImage: UIImage) {
        self.sourceImage = sourceImage
        saveSnapshot()
    }

    public func rotate90() {
        recordHistory()
        rotationDegrees = (rotationDegrees + 90) % 360
        HapticService.shared.impact(.light)
    }

    public func reset() {
        recordHistory()
        cropRect = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
        rotationDegrees = 0
        zoomScale = 1.0
        HapticService.shared.impact(.medium)
    }

    public func recordHistory() {
        let snapshot = CropStateSnapshot(cropRect: cropRect, rotationDegrees: rotationDegrees)
        undoStack.append(snapshot)
        redoStack.removeAll()
        updateUndoRedoStatus()
    }

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        let current = CropStateSnapshot(cropRect: cropRect, rotationDegrees: rotationDegrees)
        redoStack.append(current)
        applySnapshot(previous)
        updateUndoRedoStatus()
        HapticService.shared.impact(.light)
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        let current = CropStateSnapshot(cropRect: cropRect, rotationDegrees: rotationDegrees)
        undoStack.append(current)
        applySnapshot(next)
        updateUndoRedoStatus()
        HapticService.shared.impact(.light)
    }

    private func applySnapshot(_ snapshot: CropStateSnapshot) {
        self.cropRect = snapshot.cropRect
        self.rotationDegrees = snapshot.rotationDegrees
    }

    private func saveSnapshot() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateUndoRedoStatus()
    }

    private func updateUndoRedoStatus() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    /// Trims the source image to the cropped boundary, applying rotation.
    public func produceCroppedImage() -> UIImage {
        // Step 1: Rotate image if necessary
        let rotated = rotatedImage(sourceImage, byDegrees: rotationDegrees)

        // Step 2: Crop to normalized rect
        let imageSize = rotated.size
        let cropPixelRect = CGRect(
            x: cropRect.origin.x * imageSize.width,
            y: cropRect.origin.y * imageSize.height,
            width: cropRect.size.width * imageSize.width,
            height: cropRect.size.height * imageSize.height
        )

        guard let cgImage = rotated.cgImage?.cropping(to: cropPixelRect) else {
            return rotated
        }

        return UIImage(cgImage: cgImage, scale: rotated.scale, orientation: rotated.imageOrientation)
    }

    private func rotatedImage(_ image: UIImage, byDegrees degrees: Int) -> UIImage {
        if degrees == 0 { return image }

        let radians = CGFloat(degrees) * .pi / 180.0
        var newSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians)).size
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage ?? image
    }
}
