import SwiftUI

/// App preferences and lifetime storage savings tracker.
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @AppStorage("haptics_enabled") public var hapticsEnabled: Bool = true
    @AppStorage("confirm_before_delete") public var confirmBeforeDelete: Bool = true
    @AppStorage("total_freed_bytes_lifetime") public var totalFreedBytesLifetime: Int64 = 0
    @AppStorage("total_items_deleted_lifetime") public var totalItemsDeletedLifetime: Int = 0
    @AppStorage("app_appearance") public var appAppearance: Int = 1 // 0: System, 1: Dark (Cyber cleaner), 2: Light

    private init() {}

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
