import SwiftUI

@main
struct TraceCamApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(colorScheme)
                .accentColor(Color(red: 0.54, green: 0.28, blue: 0.98)) // Violet brand color
        }
    }

    private var colorScheme: ColorScheme? {
        switch settings.appAppearance {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}
