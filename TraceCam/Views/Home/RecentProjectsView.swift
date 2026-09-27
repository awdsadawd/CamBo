import SwiftUI

/// Horizontal row displaying the last 5 traced projects for quick resumption.
public struct RecentProjectsView: View {
    @ObservedObject var historyStore = ProjectHistoryStore.shared
    public let onSelect: (ProjectItem) -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Projects")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(historyStore.recentProjects.count) of 5")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            if historyStore.recentProjects.isEmpty {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.secondary)
                    Text("Your recent drawings will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(historyStore.recentProjects) { project in
                            projectCard(for: project)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func projectCard(for project: ProjectItem) -> some View {
        Button(action: {
            HapticService.shared.selection()
            onSelect(project)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    if let thumb = historyStore.loadThumbnail(for: project) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }

                    // Mode Icon Badge
                    Image(systemName: project.mode == .camera ? "camera.viewfinder" : "ipad.and.iphone")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(Color.black.opacity(0.65)))
                        .padding(6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.mode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(project.formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(width: 120, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: {
                withAnimation {
                    historyStore.deleteProject(project)
                }
            }) {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }
}
