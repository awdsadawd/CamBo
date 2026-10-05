import Foundation
import Photos
import UIKit
import AVFoundation

/// Central manager for accessing the iOS Photo Library, fetching media assets with file sizes, and performing batch deletions.
public final class PhotoLibraryManager: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = PhotoLibraryManager()

    @Published public var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published public var isAuthorized: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var loadProgress: Double = 0.0

    public let imageManager = PHCachingImageManager()

    override private init() {
        super.init()
        checkAuthorization()
    }

    public func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isAuthorized = (status == .authorized || status == .limited)
        }
    }

    public func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
            self.isAuthorized = (status == .authorized || status == .limited)
        }
        return (status == .authorized || status == .limited)
    }

    /// Fetches all media items according to filter and calculates their actual disk file sizes.
    public func fetchMediaItems(
        filter: MediaFilterType = .all,
        sort: MediaSortOption = .sizeDesc
    ) async -> [MediaItem] {
        guard isAuthorized else { return [] }

        await MainActor.run {
            self.isLoading = true
            self.loadProgress = 0.0
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]

        // Apply predicate according to filter
        switch filter {
        case .all:
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d OR mediaType == %d",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaType.video.rawValue
            )
        case .photos:
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        case .videos:
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        case .screenshots:
            fetchOptions.predicate = NSPredicate(
                format: "mediaType == %d AND (mediaSubtypes & %d) != 0",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
        case .largeVideos:
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        }

        // Fetch assets
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        let totalCount = fetchResult.count
        guard totalCount > 0 else {
            await MainActor.run { self.isLoading = false }
            return []
        }

        var items: [MediaItem] = []
        items.reserveCapacity(totalCount)

        // Process in background batches
        for index in 0..<totalCount {
            let asset = fetchResult.object(at: index)
            let size = Self.calculateDiskSize(for: asset)

            if filter == .largeVideos {
                // Filter videos >= 100MB (100 * 1024 * 1024 bytes)
                if size < 100 * 1024 * 1024 {
                    continue
                }
            }

            let item = MediaItem(asset: asset, fileSizeBytes: size)
            items.append(item)

            if index % 50 == 0 || index == totalCount - 1 {
                let progress = Double(index + 1) / Double(totalCount)
                await MainActor.run {
                    self.loadProgress = progress
                }
            }
        }

        // Sort items
        let sortedItems = sortItems(items, by: sort)

        await MainActor.run {
            self.isLoading = false
            self.loadProgress = 1.0
        }

        return sortedItems
    }

    /// Sorts a collection of MediaItems according to the specified sort option.
    public func sortItems(_ items: [MediaItem], by sort: MediaSortOption) -> [MediaItem] {
        switch sort {
        case .sizeDesc:
            return items.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
        case .sizeAsc:
            return items.sorted { $0.fileSizeBytes < $1.fileSizeBytes }
        case .dateDesc:
            return items.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        case .dateAsc:
            return items.sorted { ($0.creationDate ?? .distantFuture) < ($1.creationDate ?? .distantFuture) }
        }
    }

    /// Extracts actual disk file size for a PHAsset using PHAssetResource.
    public static func calculateDiskSize(for asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        var totalSize: Int64 = 0

        for resource in resources {
            if let num = resource.value(forKey: "fileSize") as? NSNumber {
                totalSize += num.int64Value
            } else if let intVal = resource.value(forKey: "fileSize") as? Int64 {
                totalSize += intVal
            } else if let intVal = resource.value(forKey: "fileSize") as? Int {
                totalSize += Int64(intVal)
            }
        }

        if totalSize > 0 {
            return totalSize
        }

        // Fallback estimate based on pixel dimensions and duration
        if asset.mediaType == .video {
            let estimatedBitrate: Double = 12_000_000 // 12 Mbps
            let durationSeconds = max(asset.duration, 1.0)
            return Int64((estimatedBitrate * durationSeconds) / 8.0)
        } else {
            let rawPixels = Double(asset.pixelWidth * asset.pixelHeight)
            return Int64(max(rawPixels * 0.45, 1_500_000))
        }
    }

    /// Request a thumbnail image for displaying in grids or cards.
    public func requestThumbnail(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 300, height: 300),
        completion: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    /// Request a high-resolution full image for previewing or swiping.
    public func requestFullImage(
        for asset: PHAsset,
        completion: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact

        return imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    /// Request an AVPlayerItem for playing video assets.
    public func requestVideo(
        for asset: PHAsset,
        completion: @escaping (AVPlayerItem?) -> Void
    ) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic

        imageManager.requestPlayerItem(forVideo: asset, options: options) { playerItem, _ in
            DispatchQueue.main.async {
                completion(playerItem)
            }
        }
    }

    /// Deletes the given assets using the system PHPhotoLibrary dialog.
    public func deleteAssets(_ items: [MediaItem]) async -> Result<Int, Error> {
        guard !items.isEmpty else { return .success(0) }
        let assetsToDelete = items.map { $0.asset }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        HapticManager.shared.deletionSuccess()
                        continuation.resume(returning: .success(items.count))
                    } else {
                        continuation.resume(returning: .failure(error ?? NSError(domain: "GallerySpaceOpener", code: -1, userInfo: [NSLocalizedDescriptionKey: "Deletion was cancelled or failed."])))
                    }
                }
            }
        }
    }
}
