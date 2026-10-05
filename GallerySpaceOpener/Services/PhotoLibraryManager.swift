import Foundation
import Photos
import UIKit
import AVFoundation

/// Central manager for accessing the iOS Photo Library, fetching media assets with file sizes, and performing batch deletions.
///
/// The full library is scanned ONCE and cached. Filters (Photos / Videos / Screenshots / Large) are applied
/// in-memory on top of that cache, which makes filter switches instant and eliminates race conditions where
/// a slow scan could overwrite the results of a newer filter selection.
public final class PhotoLibraryManager: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = PhotoLibraryManager()

    @Published public var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published public var isAuthorized: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var loadProgress: Double = 0.0

    public let imageManager = PHCachingImageManager()

    // Cache (only touched on the main actor)
    private var cachedItems: [MediaItem]? = nil
    private var loadTask: Task<[MediaItem], Never>? = nil

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

    // MARK: - Library Scan & Cache

    /// Returns every photo & video in the library (with file sizes). Scans once, then serves from cache.
    /// Concurrent callers share the same in-flight scan.
    @MainActor
    public func loadAllItems(forceRefresh: Bool = false) async -> [MediaItem] {
        guard isAuthorized else { return [] }

        if !forceRefresh, let cached = cachedItems {
            return cached
        }
        if let running = loadTask {
            return await running.value
        }

        isLoading = true
        loadProgress = 0.0

        let task = Task.detached(priority: .userInitiated) { () -> [MediaItem] in
            return PhotoLibraryManager.scanLibrary { progress in
                DispatchQueue.main.async {
                    PhotoLibraryManager.shared.loadProgress = progress
                }
            }
        }
        loadTask = task
        let items = await task.value

        cachedItems = items
        loadTask = nil
        isLoading = false
        loadProgress = 1.0
        return items
    }

    /// Fetches media items matching the filter, sorted by the given option.
    @MainActor
    public func fetchMediaItems(
        filter: MediaFilterType = .all,
        sort: MediaSortOption = .sizeDesc,
        forceRefresh: Bool = false
    ) async -> [MediaItem] {
        let all = await loadAllItems(forceRefresh: forceRefresh)
        let filtered = Self.apply(filter: filter, to: all)
        return sortItems(filtered, by: sort)
    }

    /// Removes deleted items from the cache so every screen stays in sync without a full rescan.
    @MainActor
    public func removeFromCache(ids: Set<String>) {
        guard !ids.isEmpty, let cached = cachedItems else { return }
        cachedItems = cached.filter { !ids.contains($0.id) }
    }

    /// Strict in-memory filtering based on the asset's real media type.
    public static func apply(filter: MediaFilterType, to items: [MediaItem]) -> [MediaItem] {
        switch filter {
        case .all:
            return items
        case .photos:
            return items.filter { $0.mediaType == .image }
        case .videos:
            return items.filter { $0.mediaType == .video }
        case .screenshots:
            return items.filter { $0.mediaType == .image && $0.isScreenshot }
        case .largeVideos:
            return items.filter { $0.mediaType == .video && $0.fileSizeBytes >= 100 * 1024 * 1024 }
        }
    }

    /// Heavy work: enumerates all images and videos and reads their on-disk sizes. Runs off the main thread.
    private static func scanLibrary(progress: @escaping (Double) -> Void) -> [MediaItem] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        let totalCount = fetchResult.count
        guard totalCount > 0 else { return [] }

        var items: [MediaItem] = []
        items.reserveCapacity(totalCount)

        for index in 0..<totalCount {
            let asset = fetchResult.object(at: index)
            // Safety: only keep real photos and videos
            guard asset.mediaType == .image || asset.mediaType == .video else { continue }
            let size = calculateDiskSize(for: asset)
            items.append(MediaItem(asset: asset, fileSizeBytes: size))

            if index % 100 == 0 || index == totalCount - 1 {
                progress(Double(index + 1) / Double(totalCount))
            }
        }
        return items
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

    // MARK: - Image / Video Requests

    /// Request a thumbnail image for displaying in grids or cards.
    @discardableResult
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
    @discardableResult
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

    // MARK: - Deletion

    /// Deletes the given assets using the system PHPhotoLibrary dialog.
    @MainActor
    public func deleteAssets(_ items: [MediaItem]) async -> Result<Int, Error> {
        guard !items.isEmpty else { return .success(0) }
        let assetsToDelete = items.map { $0.asset }

        let outcome: (Bool, Error?) = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }) { success, error in
                continuation.resume(returning: (success, error))
            }
        }

        if outcome.0 {
            HapticManager.shared.deletionSuccess()
            removeFromCache(ids: Set(items.map { $0.id }))
            return .success(items.count)
        } else {
            return .failure(outcome.1 ?? NSError(
                domain: "GallerySpaceOpener",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Deletion was cancelled or failed."]
            ))
        }
    }
}
