import Foundation
import UIKit

/// Manages persistence of recent trace projects (up to 5) on-device.
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

    /// Saves or updates a project session with its image and thumbnail.
    /// When updating an existing project (existingId != nil), preserves original createdAt
    /// and accumulates totalTimeSpent.
    @discardableResult
    public func saveProject(
        image: UIImage,
        mode: DrawingMode,
        overlayState: TraceOverlayState,
        existingId: UUID? = nil,
        sessionDuration: TimeInterval = 0
    ) -> ProjectItem? {
        let projectId = existingId ?? UUID()
        let imageFileName = "\(projectId.uuidString)_image.png"
        let thumbFileName = "\(projectId.uuidString)_thumb.png"

        let imageURL = storageDirectory.appendingPathComponent(imageFileName)
        let thumbURL = storageDirectory.appendingPathComponent(thumbFileName)

        // Generate thumbnail
        let thumbnail = createThumbnail(from: image, targetSize: CGSize(width: 200, height: 200))

        guard let imageData = image.pngData(),
              let thumbData = thumbnail.pngData() else {
            return nil
        }

        try? imageData.write(to: imageURL, options: .atomic)
        try? thumbData.write(to: thumbURL, options: .atomic)

        // Preserve original creation date and accumulate time when updating existing project
        var originalCreatedAt = Date()
        var accumulatedTime: TimeInterval = 0
        if let existingProject = recentProjects.first(where: { $0.id == projectId }) {
            originalCreatedAt = existingProject.createdAt
            accumulatedTime = existingProject.totalTimeSpent
        }

        let item = ProjectItem(
            id: projectId,
            createdAt: originalCreatedAt,
            lastModifiedAt: Date(),
            mode: mode,
            imageFileName: imageFileName,
            thumbnailFileName: thumbFileName,
            overlayState: overlayState,
            totalTimeSpent: accumulatedTime + sessionDuration
        )

        // Remove existing entry with same ID (we're replacing it)
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

    public func loadImage(for project: ProjectItem) -> UIImage? {
        let fileURL = storageDirectory.appendingPathComponent(project.imageFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
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

    /// Returns the project with the most accumulated drawing time, or nil if empty.
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
        let imgURL = storageDirectory.appendingPathComponent(project.imageFileName)
        let thumbURL = storageDirectory.appendingPathComponent(project.thumbnailFileName)
        try? fileManager.removeItem(at: imgURL)
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
