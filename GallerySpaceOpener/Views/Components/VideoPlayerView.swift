import SwiftUI
import AVKit
import Photos

/// Inline video player component for playing video assets inside swipe cards and preview modals.
///
/// The player is fully torn down (paused + item released) whenever the view disappears or the asset changes,
/// so audio never keeps playing in the background after switching tabs or swiping to the next card.
public struct VideoPlayerView: View {
    public let asset: PHAsset
    public let autoPlay: Bool

    @State private var player: AVPlayer? = nil
    @State private var isVisible: Bool = false
    @State private var requestToken: UUID = UUID()

    public init(asset: PHAsset, autoPlay: Bool = true) {
        self.asset = asset
        self.autoPlay = autoPlay
    }

    public var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .onAppear {
            isVisible = true
            loadVideo()
        }
        .onDisappear {
            isVisible = false
            tearDown()
        }
        .onChange(of: asset.localIdentifier) { _ in
            tearDown()
            loadVideo()
        }
    }

    private func loadVideo() {
        guard player == nil else { return }
        let token = UUID()
        requestToken = token
        let targetId = asset.localIdentifier

        PhotoLibraryManager.shared.requestVideo(for: asset) { playerItem in
            // Ignore late results: view gone, newer request started, or asset changed
            guard isVisible,
                  requestToken == token,
                  asset.localIdentifier == targetId,
                  let item = playerItem else { return }

            let avPlayer = AVPlayer(playerItem: item)
            player = avPlayer
            if autoPlay {
                avPlayer.play()
            }
        }
    }

    private func tearDown() {
        requestToken = UUID() // invalidate any in-flight request
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}
