import SwiftUI
import AVKit
import Photos

/// Inline video player component for playing video assets inside swipe cards and preview modals.
public struct VideoPlayerView: View {
    public let asset: PHAsset
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false

    public init(asset: PHAsset) {
        self.asset = asset
    }

    public var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        isPlaying = true
                    }
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .onAppear {
                        loadVideo()
                    }
            }
        }
    }

    private func loadVideo() {
        PhotoLibraryManager.shared.requestVideo(for: asset) { playerItem in
            if let item = playerItem {
                let avPlayer = AVPlayer(playerItem: item)
                self.player = avPlayer
            }
        }
    }
}
