import Foundation
import UIKit

/// Represents a saved recent project session for quick resume.
public struct ProjectItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var createdAt: Date
    public var lastModifiedAt: Date
    public var mode: DrawingMode
    public var imageFileName: String
    public var thumbnailFileName: String
    public var overlayState: TraceOverlayState
    public var totalTimeSpent: TimeInterval // Accumulated drawing time in seconds

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date(),
        mode: DrawingMode = .camera,
        imageFileName: String,
        thumbnailFileName: String,
        overlayState: TraceOverlayState = .default,
        totalTimeSpent: TimeInterval = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.mode = mode
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.overlayState = overlayState
        self.totalTimeSpent = totalTimeSpent
    }

    public var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastModifiedAt, relativeTo: Date())
    }

    /// Formats accumulated drawing time as "1h 23m", "45m", or "<1m".
    public var formattedTimeSpent: String {
        let total = Int(totalTimeSpent)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}
