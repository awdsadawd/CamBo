import SwiftUI

/// Dashboard displaying storage analytics, lifetime space freed milestone, and quick clean shortcuts.
public struct StorageStatsView: View {
    @ObservedObject var settings = AppSettings.shared
    public let onTriggerQuickClean: (MediaFilterType) -> Void

    public init(onTriggerQuickClean: @escaping (MediaFilterType) -> Void) {
        self.onTriggerQuickClean = onTriggerQuickClean
    }

    public var body: some View {
        NavigationStack {
            List {
                // Lifetime Reclaimed Storage Hero Banner
                Section {
                    VStack(spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green, Color.mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 58, height: 58)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Storage Freed Lifetime")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(settings.formattedLifetimeFreed)
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                        }

                        HStack {
                            Label("\(settings.totalItemsDeletedLifetime) files deleted", systemImage: "trash.circle.fill")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Quick Clean Shortcuts
                Section("Smart Clean Shortcuts") {
                    quickCleanRow(
                        title: "Large Videos (>100MB)",
                        subtitle: "Target high-definition & long recordings",
                        icon: "flame.fill",
                        color: .red,
                        filter: .largeVideos
                    )

                    quickCleanRow(
                        title: "Screenshots",
                        subtitle: "Clean temporary receipts & screen captures",
                        icon: "iphone",
                        color: .blue,
                        filter: .screenshots
                    )

                    quickCleanRow(
                        title: "All Videos",
                        subtitle: "Review all video storage consumers",
                        icon: "video.fill",
                        color: .purple,
                        filter: .videos
                    )
                }

                // Settings
                Section("Preferences") {
                    Toggle("Tactile Haptic Feedback", isOn: $settings.hapticsEnabled)

                    Toggle("Confirm Before Deleting", isOn: $settings.confirmBeforeDelete)
                }

                // About
                Section("About") {
                    HStack {
                        Text("App Name")
                        Spacer()
                        Text("GallerySpaceOpener")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Privacy")
                        Spacer()
                        Text("100% On-Device")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Storage & Stats")
        }
    }

    private func quickCleanRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        filter: MediaFilterType
    ) -> some View {
        Button(action: {
            onTriggerQuickClean(filter)
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
