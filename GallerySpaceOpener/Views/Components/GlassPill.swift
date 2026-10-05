import SwiftUI

/// A frosted glass pill container used across GallerySpaceOpener for badges and controls.
public struct GlassPill<Content: View>: View {
    public let content: Content
    public let cornerRadius: CGFloat
    public let backgroundColor: Color

    public init(
        cornerRadius: CGFloat = 16,
        backgroundColor: Color = Color.black.opacity(0.65),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}
