import Foundation

/// Holds lifetime and session cleanup statistics.
public struct CleaningSessionStats: Codable {
    public var totalBytesFreed: Int64
    public var totalItemsDeleted: Int
    public var sessionsCompleted: Int

    public init(totalBytesFreed: Int64 = 0, totalItemsDeleted: Int = 0, sessionsCompleted: Int = 0) {
        self.totalBytesFreed = totalBytesFreed
        self.totalItemsDeleted = totalItemsDeleted
        self.sessionsCompleted = sessionsCompleted
    }

    public var formattedFreedSpace: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytesFreed)
    }
}
