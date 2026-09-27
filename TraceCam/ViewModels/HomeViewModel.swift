import SwiftUI
import PhotosUI
import Combine

/// Coordinates Home screen actions: Photo picker, camera capture, and recent project resumption.
@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public var selectedPickerItem: PhotosPickerItem? = nil {
        didSet {
            Task {
                await loadPickedImage()
            }
        }
    }

    @Published public var pickedImage: UIImage? = nil      // Original uncropped image
    @Published public var croppedImage: UIImage? = nil     // Cropped reference image for direct resume
    @Published public var showCameraCaptureSheet: Bool = false
    @Published public var showSettingsSheet: Bool = false
    @Published public var isProcessingImage: Bool = false
    @Published public var errorMessage: String? = nil

    // Navigation triggers
    @Published public var shouldNavigateToCrop: Bool = false
    @Published public var resumedProject: ProjectItem? = nil

    public let historyStore = ProjectHistoryStore.shared

    public init() {}

    public func loadPickedImage() async {
        guard let item = selectedPickerItem else { return }
        isProcessingImage = true
        errorMessage = nil

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let normalizedImage = image.normalized()
                self.pickedImage = normalizedImage
                self.croppedImage = nil
                self.resumedProject = nil
                self.shouldNavigateToCrop = true
            } else {
                self.errorMessage = "Could not load image format."
            }
        } catch {
            self.errorMessage = "Failed to load selected photo: \(error.localizedDescription)"
        }

        isProcessingImage = false
        selectedPickerItem = nil
    }

    public func handleCapturedPhoto(_ image: UIImage) {
        let normalized = image.normalized()
        self.pickedImage = normalized
        self.croppedImage = nil
        self.resumedProject = nil
        self.shouldNavigateToCrop = true
    }

    /// Resumes a project into CameraTraceView directly with its cropped image and full original image.
    public func resumeProject(_ project: ProjectItem) {
        guard let cropped = historyStore.loadCroppedImage(for: project) else {
            errorMessage = "Project reference image could not be found."
            return
        }
        self.croppedImage = cropped
        self.pickedImage = historyStore.loadOriginalImage(for: project) ?? cropped
        self.resumedProject = project
    }

    /// Loads the FULL original uncropped image for re-cropping.
    public func recropProject(_ project: ProjectItem) {
        guard let original = historyStore.loadOriginalImage(for: project) else {
            errorMessage = "Original photo could not be found."
            return
        }
        self.pickedImage = original
        self.croppedImage = nil
        self.resumedProject = project
        self.shouldNavigateToCrop = true
    }

    public func deleteProject(_ project: ProjectItem) {
        historyStore.deleteProject(project)
    }

    public func toggleFavorite(_ project: ProjectItem) {
        historyStore.toggleFavorite(for: project)
    }
}

// Helper to normalize UIImage orientation
extension UIImage {
    func normalized() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}
