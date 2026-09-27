import Foundation

/// The drawing mode selected by the user.
public enum DrawingMode: String, CaseIterable, Identifiable, Codable {
    case camera = "camera"
    case screen = "screen"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .camera:
            return "Draw with Camera"
        case .screen:
            return "Draw with Screen"
        }
    }

    public var tag: String {
        switch self {
        case .camera:
            return "Popular"
        case .screen:
            return "Easy"
        }
    }

    public var tagColorHex: String {
        switch self {
        case .camera:
            return "#E02885" // Hot pink / Magenta
        case .screen:
            return "#0BB398" // Cyan / Teal
        }
    }

    public var subtitle: String {
        switch self {
        case .camera:
            return "Draw and trace through your camera. Just use a tripod, a glass, or books to hold your phone."
        case .screen:
            return "Place paper directly on your phone's screen. Follow the visible lines and start drawing."
        }
    }

    public var systemIcon: String {
        switch self {
        case .camera:
            return "camera.viewfinder"
        case .screen:
            return "ipad.and.iphone"
        }
    }
}
