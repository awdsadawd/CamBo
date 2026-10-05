import SwiftUI

/// Main Tab Bar container hosting the Explorer, Tinder-like Swiper, and Stats dashboard.
public struct MainTabView: View {
    @StateObject private var galleryVM = GalleryViewModel()
    @StateObject private var swipeCleanVM = SwipeCleanViewModel()
    @State private var selectedTab: Int = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Storage Explorer
            GalleryExplorerView(viewModel: galleryVM) {
                // Open Tinder mode
                selectedTab = 1
            }
            .tabItem {
                Label("Explorer", systemImage: "square.grid.2x2.fill")
            }
            .tag(0)

            // Tab 2: Tinder-like Swipe Cleaner
            SwipeCleanDeckView(viewModel: swipeCleanVM)
                .tabItem {
                    Label("Tinder Clean", systemImage: "flame.fill")
                }
                .tag(1)

            // Tab 3: Storage & Stats
            StorageStatsView { quickFilter in
                // Quick clean shortcut triggers Tinder mode with that filter
                Task {
                    await swipeCleanVM.prepareDeck(filter: quickFilter)
                    selectedTab = 1
                }
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            .tag(2)
        }
    }
}
