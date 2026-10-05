import Foundation
import Photos
import UIKit

/// Represents a photo or video asset with cached file size, metadata, and deletion state.
public final class MediaItem: Identifiable, ObservableObject, Hashable, @unchecked Sendable {
    public let id: String
    public let asset: PHAsset
    public let fileSizeBytes: Int64
    public let formattedFileSize: String
    public let creationDate: Date?
    public let formattedDate: String
    public let mediaType: PHAssetMediaType
    public let duration: TimeInterval
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let isScreenshot: Bool
    public let isFavorite: Bool
    public let isLivePhoto: Bool

    @Published public var isMarkedForDeletion: Bool = false

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    public init(asset: PHAsset, fileSizeBytes: Int64) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.fileSizeBytes = fileSizeBytes
        self.formattedFileSize = Self.byteFormatter.string(fromByteCount: fileSizeBytes)
        self.creationDate = asset.creationDate
        if let date = asset.creationDate {
            self.formattedDate = Self.dateFormatter.string(from: date)
        } else {
            self.formattedDate = "Unknown Date"
        }
        self.mediaType = asset.mediaType
        self.duration = asset.duration
        self.pixelWidth = asset.pixelWidth
        self.pixelHeight = asset.pixelHeight
        self.isFavorite = asset.isFavorite
        self.isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
        self.isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
    }

    public var isVideo: Bool {
        mediaType == .video
    }

    public var formattedDuration: String {
        guard isVideo else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var resolutionString: String {
        guard pixelWidth > 0 && pixelHeight > 0 else { return "Standard" }
        let megapixels = Double(pixelWidth * pixelHeight) / 1_000_000.0
        if megapixels >= 1.0 {
            return "\(pixelWidth) × \(pixelHeight) (\(String(format: "%.1f", megapixels)) MP)"
        } else {
            return "\(pixelWidth) × \(pixelHeight)"
        }
    }

    public static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
