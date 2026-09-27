import SwiftUI

public enum ProjectFilterTab: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
}

/// Horizontal row displaying recent projects with time tracking, favorites section, delete controls, and "most drawn" crown.
public struct RecentProjectsView: View {
    @ObservedObject var historyStore = ProjectHistoryStore.shared
    public let onSelect: (ProjectItem) -> Void
    public var onRecrop: ((ProjectItem) -> Void)? = nil

    @State private var selectedTab: ProjectFilterTab = .all
    @State private var showDeleteAllConfirm: Bool = false

    public init(
        onSelect: @escaping (ProjectItem) -> Void,
        onRecrop: ((ProjectItem) -> Void)? = nil
    ) {
        self.onSelect = onSelect
        self.onRecrop = onRecrop
    }

    private var displayedProjects: [ProjectItem] {
        switch selectedTab {
        case .all:
            return historyStore.recentProjects
        case .favorites:
            return historyStore.favoriteProjects
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Title & Total Drawing Time
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recent Projects")
                        .font(.system(size: 19, weight: .bold))
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
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
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

            // Section Filter Tabs: [ All (5) | Favorites ❤️ (2) ]
            HStack(spacing: 8) {
                // All Tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .all
                    }
                    HapticService.shared.selection()
                }) {
                    Text("All (\(historyStore.recentProjects.count))")
                        .font(.system(size: 13, weight: selectedTab == .all ? .bold : .medium))
                        .foregroundColor(selectedTab == .all ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedTab == .all ?
                            Capsule().fill(Color(red: 0.54, green: 0.28, blue: 0.98)) :
                            Capsule().fill(Color(.secondarySystemBackground))
                        )
                }
                .buttonStyle(.plain)

                // Favorites Tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .favorites
                    }
                    HapticService.shared.selection()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundColor(selectedTab == .favorites ? .white : .red)
                        Text("Favorites (\(historyStore.favoriteProjects.count))")
                            .font(.system(size: 13, weight: selectedTab == .favorites ? .bold : .medium))
                            .foregroundColor(selectedTab == .favorites ? .white : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        selectedTab == .favorites ?
                        Capsule().fill(Color.red) :
                        Capsule().fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)

            // Projects List or Empty State
            if displayedProjects.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: selectedTab == .favorites ? "heart.slash" : "clock.arrow.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)

                    Text(selectedTab == .favorites ? "No favorites yet. Tap ❤️ on any artwork to add it here!" : "Your recent drawings will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(displayedProjects) { project in
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
                ZStack(alignment: .top) {
                    // Thumbnail
                    if let thumb = historyStore.loadThumbnail(for: project) {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 130, height: 130)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 130, height: 130)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    }

                    // Card Overlays (Delete left, Badges & Favorite right)
                    HStack(alignment: .top) {
                        // Quick manual delete button (X)
                        Button {
                            withAnimation { historyStore.deleteProject(project) }
                            HapticService.shared.impact(.light)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.65)))
                        }

                        Spacer()

                        VStack(spacing: 5) {
                            // Favorite Heart Button (Instant tap!)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    historyStore.toggleFavorite(for: project)
                                }
                                HapticService.shared.impact(.light)
                            } label: {
                                Image(systemName: project.isFavorite ? "heart.fill" : "heart")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(project.isFavorite ? .red : .white)
                                    .padding(6)
                                    .background(Circle().fill(Color.black.opacity(0.65)))
                            }

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
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Circle().fill(Color.black.opacity(0.65)))
                        }
                    }
                    .padding(7)
                }

                VStack(alignment: .leading, spacing: 3) {
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
                .frame(width: 130, alignment: .leading)
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

            Button {
                withAnimation { historyStore.toggleFavorite(for: project) }
            } label: {
                Label(project.isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: project.isFavorite ? "heart.slash" : "heart.fill")
            }

            Button(role: .destructive) {
                withAnimation { historyStore.deleteProject(project) }
            } label: {
                Label("Delete Project", systemImage: "trash")
            }
        }
    }
}
