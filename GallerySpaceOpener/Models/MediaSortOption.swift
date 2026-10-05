import SwiftUI

/// Sorting modes for photos and videos in the gallery.
public enum MediaSortOption: String, CaseIterable, Identifiable, Sendable {
    case sizeDesc = "Biggest First"
    case sizeAsc = "Smallest First"
    case dateDesc = "Newest First"
    case dateAsc = "Oldest First"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .sizeDesc: return "arrow.down.square.fill"
        case .sizeAsc: return "arrow.up.square.fill"
        case .dateDesc: return "clock.arrow.circlepath"
        case .dateAsc: return "calendar"
        }
    }
}
