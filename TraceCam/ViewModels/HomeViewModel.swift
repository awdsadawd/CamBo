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

    @Published public var pickedImage: UIImage? = nil
    @Published public var showCameraCaptureSheet: Bool = false
    @Published public var showSettingsSheet: Bool = false
    @Published public var isProcessingImage: Bool = false
    @Published public var errorMessage: String? = nil

    // Navigation triggers
    @Published public var shouldNavigateToCrop: Bool = false
    @Published public var resumedProject: ProjectItem? = nil

    private let historyStore = ProjectHistoryStore.shared

    public init() {}

    public func loadPickedImage() async {
        guard let item = selectedPickerItem else { return }
        isProcessingImage = true
        errorMessage = nil

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                // Normalize orientation
                let normalizedImage = image.normalized()
                self.pickedImage = normalizedImage
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
        self.resumedProject = nil
        self.shouldNavigateToCrop = true
    }

    public func resumeProject(_ project: ProjectItem) {
        guard let image = historyStore.loadImage(for: project) else {
            errorMessage = "Project reference image could not be found."
            return
        }
        self.pickedImage = image
        self.resumedProject = project
    }

    public func deleteProject(_ project: ProjectItem) {
        historyStore.deleteProject(project)
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
