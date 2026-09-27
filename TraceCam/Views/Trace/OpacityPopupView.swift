import SwiftUI

/// Opacity adjustment popup panel shown above the toolbar (matching ARtie Lab Screenshot 4).
public struct OpacityPopupView: View {
    @Binding var opacity: Double
    public let onClose: () -> Void

    public var body: some View {
        GlassCard(cornerRadius: 20, backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.92)) {
            VStack(spacing: 14) {
                // Header
                HStack {
                    Spacer()
                    Text("Opacity")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .overlay(
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticService.shared.selection()
                            onClose()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(6)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                    }
                )

                // Slider Row
                HStack(spacing: 14) {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.4))

                    Slider(
                        value: $opacity,
                        in: 0.05...1.0,
                        step: 0.01
                    )
                    .tint(Color(red: 0.54, green: 0.28, blue: 0.98))

                    Image(systemName: "photo.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
    }
}
