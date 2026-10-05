import SwiftUI

/// Filters for the media library grid and swipe cleaner.
public enum MediaFilterType: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"
    case screenshots = "Screenshots"
    case largeVideos = "Large (>100MB)"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .photos: return "photo.fill"
        case .videos: return "video.fill"
        case .screenshots: return "iphone"
        case .largeVideos: return "flame.fill"
        }
    }
}
