import SwiftUI

/// Horizontal row displaying recent projects with time tracking, delete controls, and "most drawn" crown.
public struct RecentProjectsView: View {
    @ObservedObject var historyStore = ProjectHistoryStore.shared
    public let onSelect: (ProjectItem) -> Void
    public var onRecrop: ((ProjectItem) -> Void)? = nil

    @State private var showDeleteAllConfirm: Bool = false

    public init(
        onSelect: @escaping (ProjectItem) -> Void,
        onRecrop: ((ProjectItem) -> Void)? = nil
    ) {
        self.onSelect = onSelect
        self.onRecrop = onRecrop
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with total time and delete all
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Projects")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    if !historyStore.recentProjects.isEmpty {
                        Text("Total drawing time: \(historyStore.formattedTotalTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !historyStore.recentProjects.isEmpty {
                    Button(action: { showDeleteAllConfirm = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Clear All")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.1)))
                    }
                    .alert("Delete All Projects?", isPresented: $showDeleteAllConfirm) {
                        Button("Cancel", role: .cancel) {}
                        Button("Delete All", role: .destructive) {
                            withAnimation { historyStore.deleteAllProjects() }
                            HapticService.shared.notification(.warning)
                        }
                    } message: {
                        Text("This will remove all \(historyStore.recentProjects.count) recent projects and their saved images.")
                    }
                }
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
        let isMostUsed = historyStore.mostUsedProject?.id == project.id && project.totalTimeSpent > 0

        return Button(action: {
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
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    }

                    // Top-left: quick manual delete button
                    HStack {
                        Button {
                            withAnimation { historyStore.deleteProject(project) }
                            HapticService.shared.impact(.light)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Circle().fill(Color.black.opacity(0.65)))
                        }
                        .padding(6)

                        Spacer()
                    }
                    .frame(width: 120, alignment: .leading)

                    // Top-right badges
                    VStack(spacing: 4) {
                        // Crown for most-used project
                        if isMostUsed {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                                .padding(5)
                                .background(Circle().fill(Color.black.opacity(0.7)))
                        }

                        // Mode icon
                        Image(systemName: project.mode == .camera ? "camera.viewfinder" : "ipad.and.iphone")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Circle().fill(Color.black.opacity(0.65)))
                    }
                    .padding(6)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.mode.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Time spent on this project
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(project.formattedTimeSpent)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isMostUsed ? Color(red: 0.54, green: 0.28, blue: 0.98) : .secondary)

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
            Button {
                onSelect(project)
            } label: {
                Label("Resume Drawing", systemImage: "pencil.tip.crop.circle")
            }

            if let onRecrop = onRecrop {
                Button {
                    onRecrop(project)
                } label: {
                    Label("Re-crop Image", systemImage: "crop")
                }
            }

            Button(role: .destructive) {
                withAnimation { historyStore.deleteProject(project) }
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }
}
