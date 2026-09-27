import SwiftUI
import Combine

/// Persistent user settings for default trace opacity, zoom, and haptic feedback.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    private enum Keys {
        static let defaultOpacity = "tracecam_default_opacity"
        static let defaultZoom = "tracecam_default_zoom"
        static let hapticsEnabled = "tracecam_haptics_enabled"
        static let appAppearance = "tracecam_app_appearance"
    }

    @Published public var defaultOpacity: Double {
        didSet {
            UserDefaults.standard.set(defaultOpacity, forKey: Keys.defaultOpacity)
        }
    }

    @Published public var defaultZoom: Double {
        didSet {
            UserDefaults.standard.set(defaultZoom, forKey: Keys.defaultZoom)
        }
    }

    @Published public var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
            HapticService.shared.isEnabled = hapticsEnabled
        }
    }

    @Published public var appAppearance: String { // "system", "dark", "light"
        didSet {
            UserDefaults.standard.set(appAppearance, forKey: Keys.appAppearance)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.defaultOpacity = defaults.object(forKey: Keys.defaultOpacity) != nil ? defaults.double(forKey: Keys.defaultOpacity) : 0.5
        self.defaultZoom = defaults.object(forKey: Keys.defaultZoom) != nil ? defaults.double(forKey: Keys.defaultZoom) : 1.0
        self.hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) != nil ? defaults.bool(forKey: Keys.hapticsEnabled) : true
        self.appAppearance = defaults.string(forKey: Keys.appAppearance) ?? "system"

        HapticService.shared.isEnabled = self.hapticsEnabled
    }
}
