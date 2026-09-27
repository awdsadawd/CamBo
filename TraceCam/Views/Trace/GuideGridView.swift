import SwiftUI

/// Renders guide lines (Rule of Thirds, 3x3 fine grid, or Center Crosshair) to assist drawing proportions.
public struct GuideGridView: View {
    public let type: GuideOverlayType
    public var lineColor: Color = Color.white.opacity(0.45)
    public var lineWidth: CGFloat = 1.0

    public init(type: GuideOverlayType, lineColor: Color = Color.white.opacity(0.45), lineWidth: CGFloat = 1.0) {
        self.type = type
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                switch type {
                case .none:
                    break

                case .ruleOfThirds, .grid3x3:
                    // Vertical lines (1/3 and 2/3)
                    path.move(to: CGPoint(x: w / 3, y: 0))
                    path.addLine(to: CGPoint(x: w / 3, y: h))

                    path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                    path.addLine(to: CGPoint(x: 2 * w / 3, y: h))

                    // Horizontal lines (1/3 and 2/3)
                    path.move(to: CGPoint(x: 0, y: h / 3))
                    path.addLine(to: CGPoint(x: w, y: h / 3))

                    path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                    path.addLine(to: CGPoint(x: w, y: 2 * h / 3))

                case .crosshair:
                    // Center vertical
                    path.move(to: CGPoint(x: w / 2, y: 0))
                    path.addLine(to: CGPoint(x: w / 2, y: h))

                    // Center horizontal
                    path.move(to: CGPoint(x: 0, y: h / 2))
                    path.addLine(to: CGPoint(x: w, y: h / 2))

                    // Center circle
                    let radius: CGFloat = 20
                    path.addEllipse(in: CGRect(x: w / 2 - radius, y: h / 2 - radius, width: radius * 2, height: radius * 2))
                }
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, dash: type == .ruleOfThirds ? [4, 4] : []))
        }
        .allowsHitTesting(false)
    }
}
