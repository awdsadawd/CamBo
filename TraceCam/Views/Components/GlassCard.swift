import SwiftUI

/// Reusable dark frosted glass container for controls and toolbars.
public struct GlassCard<Content: View>: View {
    public var cornerRadius: CGFloat = 24
    public var backgroundColor: Color = Color.black.opacity(0.65)
    public let content: () -> Content

    public init(
        cornerRadius: CGFloat = 24,
        backgroundColor: Color = Color.black.opacity(0.65),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.content = content
    }

    public var body: some View {
        content()
            .background(.ultraThinMaterial)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)
    }
}

/// Floating toast alert for user actions like locking or resetting.
public struct ToastView: View {
    public let message: String

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(red: 0.54, green: 0.28, blue: 0.98))
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(radius: 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
