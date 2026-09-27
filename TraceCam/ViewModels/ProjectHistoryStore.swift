import Foundation
import UIKit
import Combine

/// Manages persistence of recent trace projects (up to 5) on-device, with favorites and original image storage.
public final class ProjectHistoryStore: ObservableObject {
    public static let shared = ProjectHistoryStore()

    @Published public private(set) var recentProjects: [ProjectItem] = []

    private let fileManager = FileManager.default
    private let historyFileName = "recent_projects.json"
    private let maxProjects = 5

    private var storageDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("TraceCamProjects", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {
        loadHistory()
    }

    public func loadHistory() {
        let fileURL = storageDirectory.appendingPathComponent(historyFileName)
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ProjectItem].self, from: data) else {
            self.recentProjects = []
            return
        }
        self.recentProjects = decoded.sorted(by: { $0.lastModifiedAt > $1.lastModifiedAt })
    }

    private func saveHistory() {
        let fileURL = storageDirectory.appendingPathComponent(historyFileName)
        guard let data = try? JSONEncoder().encode(recentProjects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Saves or updates a project session with both the cropped reference and the uncropped original.
    @discardableResult
    public func saveProject(
        croppedImage: UIImage,
        originalImage: UIImage? = nil,
        mode: DrawingMode,
        overlayState: TraceOverlayState,
        existingId: UUID? = nil,
        sessionDuration: TimeInterval = 0
    ) -> ProjectItem? {
        let projectId = existingId ?? UUID()
        let croppedFileName = "\(projectId.uuidString)_cropped.png"
        let originalFileName = "\(projectId.uuidString)_original.png"
        let thumbFileName = "\(projectId.uuidString)_thumb.png"

        let croppedURL = storageDirectory.appendingPathComponent(croppedFileName)
        let originalURL = storageDirectory.appendingPathComponent(originalFileName)
        let thumbURL = storageDirectory.appendingPathComponent(thumbFileName)

        // Save cropped image
        guard let croppedData = croppedImage.pngData() else { return nil }
        try? croppedData.write(to: croppedURL, options: .atomic)

        // Save original uncropped image if provided (or preserve existing)
        let uncroppedToSave = originalImage ?? croppedImage
        if let originalData = uncroppedToSave.pngData() {
            // Only write original if file does not exist yet or new original is passed
            if !fileManager.fileExists(atPath: originalURL.path) || originalImage != nil {
                try? originalData.write(to: originalURL, options: .atomic)
            }
        }

        // Generate thumbnail from cropped reference
        let thumbnail = createThumbnail(from: croppedImage, targetSize: CGSize(width: 200, height: 200))
        if let thumbData = thumbnail.pngData() {
            try? thumbData.write(to: thumbURL, options: .atomic)
        }

        // Preserve original creation date, accumulated time, and favorite status when updating
        var originalCreatedAt = Date()
        var accumulatedTime: TimeInterval = 0
        var isFavorite = false
        if let existingProject = recentProjects.first(where: { $0.id == projectId }) {
            originalCreatedAt = existingProject.createdAt
            accumulatedTime = existingProject.totalTimeSpent
            isFavorite = existingProject.isFavorite
        }

        let item = ProjectItem(
            id: projectId,
            createdAt: originalCreatedAt,
            lastModifiedAt: Date(),
            mode: mode,
            imageFileName: croppedFileName,
            originalImageFileName: originalFileName,
            thumbnailFileName: thumbFileName,
            overlayState: overlayState,
            totalTimeSpent: accumulatedTime + sessionDuration,
            isFavorite: isFavorite
        )

        // Remove existing entry with same ID (replacing in-place)
        recentProjects.removeAll(where: { $0.id == projectId })
        recentProjects.insert(item, at: 0)

        // Enforce max 5 items
        while recentProjects.count > maxProjects {
            let removed = recentProjects.removeLast()
            deleteProjectFiles(for: removed)
        }

        saveHistory()
        return item
    }

    /// Toggles the favorite status for a project and saves.
    public func toggleFavorite(for project: ProjectItem) {
        if let index = recentProjects.firstIndex(where: { $0.id == project.id }) {
            recentProjects[index].isFavorite.toggle()
            saveHistory()
        }
    }

    /// Filtered list of favorite projects.
    public var favoriteProjects: [ProjectItem] {
        recentProjects.filter { $0.isFavorite }
    }

    /// Loads the cropped image used in the tracing overlay.
    public func loadCroppedImage(for project: ProjectItem) -> UIImage? {
        let fileURL = storageDirectory.appendingPathComponent(project.imageFileName)
        if let data = try? Data(contentsOf: fileURL), let img = UIImage(data: data) {
            return img
        }
        return nil
    }

    /// Loads the full original uncropped image for re-cropping.
    public func loadOriginalImage(for project: ProjectItem) -> UIImage? {
        let origURL = storageDirectory.appendingPathComponent(project.originalImageFileName)
        if let data = try? Data(contentsOf: origURL), let img = UIImage(data: data) {
            return img
        }
        // Fallback to cropped if original not found
        return loadCroppedImage(for: project)
    }

    // Backwards-compatible loadImage
    public func loadImage(for project: ProjectItem) -> UIImage? {
        loadCroppedImage(for: project)
    }

    public func loadThumbnail(for project: ProjectItem) -> UIImage? {
        let fileURL = storageDirectory.appendingPathComponent(project.thumbnailFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    public func deleteProject(_ project: ProjectItem) {
        recentProjects.removeAll(where: { $0.id == project.id })
        deleteProjectFiles(for: project)
        saveHistory()
    }

    /// Deletes all recent projects and their files.
    public func deleteAllProjects() {
        for project in recentProjects {
            deleteProjectFiles(for: project)
        }
        recentProjects.removeAll()
        saveHistory()
    }

    /// Returns the project with the most accumulated drawing time.
    public var mostUsedProject: ProjectItem? {
        recentProjects.max(by: { $0.totalTimeSpent < $1.totalTimeSpent })
    }

    /// Total accumulated drawing time across all recent projects.
    public var totalDrawingTime: TimeInterval {
        recentProjects.reduce(0) { $0 + $1.totalTimeSpent }
    }

    public var formattedTotalTime: String {
        let total = Int(totalDrawingTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else if total > 0 {
            return "<1m"
        } else {
            return "0m"
        }
    }

    private func deleteProjectFiles(for project: ProjectItem) {
        let croppedURL = storageDirectory.appendingPathComponent(project.imageFileName)
        let origURL = storageDirectory.appendingPathComponent(project.originalImageFileName)
        let thumbURL = storageDirectory.appendingPathComponent(project.thumbnailFileName)
        try? fileManager.removeItem(at: croppedURL)
        try? fileManager.removeItem(at: origURL)
        try? fileManager.removeItem(at: thumbURL)
    }

    private func createThumbnail(from image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            let aspectWidth = targetSize.width / image.size.width
            let aspectHeight = targetSize.height / image.size.height
            let aspectRatio = max(aspectWidth, aspectHeight)

            let scaledWidth = image.size.width * aspectRatio
            let scaledHeight = image.size.height * aspectRatio
            let x = (targetSize.width - scaledWidth) / 2.0
            let y = (targetSize.height - scaledHeight) / 2.0

            image.draw(in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
        }
    }
}
