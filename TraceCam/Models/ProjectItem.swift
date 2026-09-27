import Foundation
import UIKit

/// Represents a saved recent project session for quick resume.
public struct ProjectItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public var lastModifiedAt: Date
    public var mode: DrawingMode
    public var imageFileName: String
    public var thumbnailFileName: String
    public var overlayState: TraceOverlayState

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date(),
        mode: DrawingMode = .camera,
        imageFileName: String,
        thumbnailFileName: String,
        overlayState: TraceOverlayState = .default
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.mode = mode
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.overlayState = overlayState
    }

    public var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastModifiedAt, relativeTo: Date())
    }
}
