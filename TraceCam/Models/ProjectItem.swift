import Foundation
import UIKit

/// Represents a saved recent project session for quick resume, with favorite status and original reference retention.
public struct ProjectItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var createdAt: Date
    public var lastModifiedAt: Date
    public var mode: DrawingMode
    public var imageFileName: String          // Cropped reference image used in tracing
    public var originalImageFileName: String  // Full uncropped original image for re-cropping
    public var thumbnailFileName: String
    public var overlayState: TraceOverlayState
    public var totalTimeSpent: TimeInterval   // Accumulated drawing time in seconds
    public var isFavorite: Bool               // Favorite status

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        lastModifiedAt: Date = Date(),
        mode: DrawingMode = .camera,
        imageFileName: String,
        originalImageFileName: String? = nil,
        thumbnailFileName: String,
        overlayState: TraceOverlayState = .default,
        totalTimeSpent: TimeInterval = 0,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastModifiedAt = lastModifiedAt
        self.mode = mode
        self.imageFileName = imageFileName
        self.originalImageFileName = originalImageFileName ?? imageFileName
        self.thumbnailFileName = thumbnailFileName
        self.overlayState = overlayState
        self.totalTimeSpent = totalTimeSpent
        self.isFavorite = isFavorite
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, lastModifiedAt, mode, imageFileName, originalImageFileName
        case thumbnailFileName, overlayState, totalTimeSpent, isFavorite
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastModifiedAt = try container.decode(Date.self, forKey: .lastModifiedAt)
        mode = try container.decode(DrawingMode.self, forKey: .mode)
        imageFileName = try container.decode(String.self, forKey: .imageFileName)
        originalImageFileName = try container.decodeIfPresent(String.self, forKey: .originalImageFileName) ?? imageFileName
        thumbnailFileName = try container.decode(String.self, forKey: .thumbnailFileName)
        overlayState = try container.decode(TraceOverlayState.self, forKey: .overlayState)
        totalTimeSpent = try container.decodeIfPresent(TimeInterval.self, forKey: .totalTimeSpent) ?? 0
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
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
        } else if total > 0 {
            return "<1m"
        } else {
            return "0m"
        }
    }
}
