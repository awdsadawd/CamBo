import Foundation
import CoreGraphics
import SwiftUI

/// Represents the spatial and visual state of the trace overlay image.
public struct TraceOverlayState: Equatable, Codable {
    public var offsetWidth: Double
    public var offsetHeight: Double
    public var scale: Double
    public var rotationDegrees: Double
    public var opacity: Double
    public var isFlipped: Bool
    public var isLocked: Bool
    public var isHidden: Bool
    public var filter: TraceFilter
    public var guideType: GuideOverlayType

    public init(
        offsetWidth: Double = 0,
        offsetHeight: Double = 0,
        scale: Double = 1.0,
        rotationDegrees: Double = 0,
        opacity: Double = 0.5,
        isFlipped: Bool = false,
        isLocked: Bool = false,
        isHidden: Bool = false,
        filter: TraceFilter = .original,
        guideType: GuideOverlayType = .none
    ) {
        self.offsetWidth = offsetWidth
        self.offsetHeight = offsetHeight
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
        self.isFlipped = isFlipped
        self.isLocked = isLocked
        self.isHidden = isHidden
        self.filter = filter
        self.guideType = guideType
    }

    public var offset: CGSize {
        CGSize(width: offsetWidth, height: offsetHeight)
    }

    public var rotation: Angle {
        Angle(degrees: rotationDegrees)
    }

    public static let `default` = TraceOverlayState()
}
