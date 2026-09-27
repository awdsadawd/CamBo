import Foundation

/// Symmetry and grid overlay types to assist with proportional drawing.
public enum GuideOverlayType: String, CaseIterable, Identifiable, Codable {
    case none = "none"
    case ruleOfThirds = "ruleOfThirds"
    case grid3x3 = "grid3x3"
    case crosshair = "crosshair"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none:
            return "None"
        case .ruleOfThirds:
            return "Rule of Thirds"
        case .grid3x3:
            return "Fine Grid"
        case .crosshair:
            return "Center Crosshair"
        }
    }

    public var iconName: String {
        switch self {
        case .none:
            return "slash.circle"
        case .ruleOfThirds:
            return "grid"
        case .grid3x3:
            return "square.grid.3x3"
        case .crosshair:
            return "plus"
        }
    }
}
