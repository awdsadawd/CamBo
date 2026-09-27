import SwiftUI
import AVFoundation

/// Wraps AVCaptureVideoPreviewLayer in a SwiftUI view.
public struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService

    public init(cameraService: CameraService = .shared) {
        self.cameraService = cameraService
    }

    public func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = cameraService.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    public func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.videoPreviewLayer.session != cameraService.session {
            uiView.videoPreviewLayer.session = cameraService.session
        }
    }
}

public class PreviewUIView: UIView {
    public override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    public var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
        if let connection = videoPreviewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}
