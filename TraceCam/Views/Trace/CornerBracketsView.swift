import SwiftUI

/// Renders signature violet corner bracket accents around the reference image frame (as seen in ARtie Lab).
public struct CornerBracketsView: View {
    public var cornerLength: CGFloat = 32
    public var lineWidth: CGFloat = 4.5
    public var color: Color = Color(red: 0.54, green: 0.28, blue: 0.98) // Vivid Violet / Purple

    public init(
        cornerLength: CGFloat = 32,
        lineWidth: CGFloat = 4.5,
        color: Color = Color(red: 0.54, green: 0.28, blue: 0.98)
    ) {
        self.cornerLength = cornerLength
        self.lineWidth = lineWidth
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // Top-Left (┌)
                path.move(to: CGPoint(x: 0, y: cornerLength))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: cornerLength, y: 0))

                // Top-Right (┐)
                path.move(to: CGPoint(x: w - cornerLength, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: cornerLength))

                // Bottom-Left (└)
                path.move(to: CGPoint(x: 0, y: h - cornerLength))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: cornerLength, y: h))

                // Bottom-Right (┘)
                path.move(to: CGPoint(x: w - cornerLength, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: h - cornerLength))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}
