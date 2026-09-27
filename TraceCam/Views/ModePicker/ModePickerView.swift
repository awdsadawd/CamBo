import SwiftUI

/// Screen 3: Drawing Mode Picker offering exactly two modes (Camera Trace and Screen Trace).
public struct ModePickerView: View {
    public let croppedImage: UIImage
    public let existingProjectId: UUID?
    public let onReturnHome: () -> Void

    @State private var selectedMode: DrawingMode = .camera
    @State private var navigateToTrace: Bool = false

    public init(croppedImage: UIImage, existingProjectId: UUID? = nil, onReturnHome: @escaping () -> Void) {
        self.croppedImage = croppedImage
        self.existingProjectId = existingProjectId
        self.onReturnHome = onReturnHome
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Option 1: Draw with Camera (Popular)
                    modeCard(
                        mode: .camera,
                        badgeText: "Popular",
                        badgeBg: Color(red: 0.91, green: 0.18, blue: 0.58),
                        icon: "camera.viewfinder"
                    )

                    // Option 2: Draw with Screen (Easy)
                    modeCard(
                        mode: .screen,
                        badgeText: "Easy",
                        badgeBg: Color(red: 0.08, green: 0.72, blue: 0.65),
                        icon: "ipad.and.iphone"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }

            Spacer()

            // Bottom Continue Button
            VStack(spacing: 12) {
                Button(action: {
                    HapticService.shared.impact(.medium)
                    navigateToTrace = true
                }) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.54, green: 0.28, blue: 0.98))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.35), radius: 10, x: 0, y: 5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .navigationTitle("Drawing Mode")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToTrace) {
            CameraTraceView(
                image: croppedImage,
                mode: selectedMode,
                existingProjectId: existingProjectId,
                onReturnHome: onReturnHome
            )
        }
    }

    private func modeCard(
        mode: DrawingMode,
        badgeText: String,
        badgeBg: Color,
        icon: String
    ) -> some View {
        let isSelected = selectedMode == mode

        return Button(action: {
            HapticService.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedMode = mode
            }
        }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    // Preview Icon / Visual
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.12) : Color(.secondarySystemBackground))
                            .frame(width: 60, height: 60)

                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(isSelected ? Color(red: 0.54, green: 0.28, blue: 0.98) : .primary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(mode.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)

                            Spacer()

                            // Tag Badge
                            Text(badgeText)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(badgeBg))
                        }

                        Text(mode.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.54, green: 0.28, blue: 0.98) : Color(.separator).opacity(0.4), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: isSelected ? Color(red: 0.54, green: 0.28, blue: 0.98).opacity(0.12) : Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
