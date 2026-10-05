import SwiftUI
import Photos

@main
struct GallerySpaceOpenerApp: App {
    @StateObject private var libraryManager = PhotoLibraryManager.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if libraryManager.isAuthorized {
                    MainTabView()
                } else {
                    photoPermissionScreen
                }
            }
            .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch settings.appAppearance {
        case 1: return .dark
        case 2: return .light
        default: return nil
        }
    }

    // MARK: - Photo Permission Screen
    private var photoPermissionScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)

                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("GallerySpaceOpener")
                    .font(.system(size: 28, weight: .heavy))

                Text("Analyze your gallery, find space-consuming files, and clean storage with Tinder-like swiping.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                featureBullet(icon: "flame.fill", title: "Tinder-like Swiping", desc: "Swipe right to delete, left to keep")
                featureBullet(icon: "arrow.down.square.fill", title: "Sort by Largest Size", desc: "Identify multi-gigabyte videos immediately")
                featureBullet(icon: "shield.checkerboard", title: "100% Private & Safe", desc: "All scans and deletions happen on your device")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 24)

            Spacer()

            if libraryManager.authorizationStatus == .denied || libraryManager.authorizationStatus == .restricted {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings to Enable Access")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            } else {
                Button(action: {
                    Task {
                        _ = await libraryManager.requestAuthorization()
                    }
                }) {
                    Text("Allow Photo Library Access")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private func featureBullet(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
