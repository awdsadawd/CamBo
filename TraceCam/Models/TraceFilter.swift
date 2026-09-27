import Foundation

/// Filter types available to enhance faint lines for tracing.
public enum TraceFilter: String, CaseIterable, Identifiable, Codable {
    case original = "original"
    case grayscale = "grayscale"
    case highContrast = "highContrast"
    case edgeDetection = "edgeDetection"
    case invert = "invert"
    case lineArt = "lineArt"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original:
            return "Original"
        case .grayscale:
            return "B&W Grayscale"
        case .highContrast:
            return "High Contrast"
        case .edgeDetection:
            return "Outline (Edges)"
        case .invert:
            return "Inverted"
        case .lineArt:
            return "Pencil Sketch"
        }
    }

    public var iconName: String {
        switch self {
        case .original:
            return "photo"
        case .grayscale:
            return "circle.lefthalf.filled"
        case .highContrast:
            return "circle.circle"
        case .edgeDetection:
            return "wand.and.stars"
        case .invert:
            return "arrow.triangle.2.circlepath"
        case .lineArt:
            return "pencil.line"
        }
    }
}
