import SwiftUI

/// App preferences and lifetime storage savings tracker.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @Published public var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "haptics_enabled") }
    }
    
    @Published public var confirmBeforeDelete: Bool {
        didSet { UserDefaults.standard.set(confirmBeforeDelete, forKey: "confirm_before_delete") }
    }
    
    @Published public var totalFreedBytesLifetime: Int64 {
        didSet { UserDefaults.standard.set(totalFreedBytesLifetime, forKey: "total_freed_bytes_lifetime") }
    }
    
    @Published public var totalItemsDeletedLifetime: Int {
        didSet { UserDefaults.standard.set(totalItemsDeletedLifetime, forKey: "total_items_deleted_lifetime") }
    }
    
    @Published public var appAppearance: Int {
        didSet { UserDefaults.standard.set(appAppearance, forKey: "app_appearance") }
    }

    private init() {
        self.hapticsEnabled = UserDefaults.standard.object(forKey: "haptics_enabled") as? Bool ?? true
        self.confirmBeforeDelete = UserDefaults.standard.object(forKey: "confirm_before_delete") as? Bool ?? true
        
        let freedObj = UserDefaults.standard.object(forKey: "total_freed_bytes_lifetime")
        if let num = freedObj as? NSNumber {
            self.totalFreedBytesLifetime = num.int64Value
        } else {
            self.totalFreedBytesLifetime = 0
        }
        
        self.totalItemsDeletedLifetime = UserDefaults.standard.integer(forKey: "total_items_deleted_lifetime")
        let savedAppearance = UserDefaults.standard.integer(forKey: "app_appearance")
        self.appAppearance = (savedAppearance == 0 && UserDefaults.standard.object(forKey: "app_appearance") == nil) ? 1 : savedAppearance
    }

    public func recordClean(bytes: Int64, count: Int) {
        totalFreedBytesLifetime += bytes
        totalItemsDeletedLifetime += count
    }

    public var formattedLifetimeFreed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalFreedBytesLifetime)
    }
}
