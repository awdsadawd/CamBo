import Foundation
import AVFoundation
import UIKit
import Combine

/// Manages AVFoundation camera capture session, device zoom, torch, and photo capture.
public final class CameraService: NSObject, ObservableObject {
    public static let shared = CameraService()

    @Published public var isRunning: Bool = false
    @Published public var isTorchOn: Bool = false
    @Published public var currentZoom: CGFloat = 1.0
    @Published public var isAuthorized: Bool = false
    @Published public var hasCameraPermissionDenied: Bool = false
    @Published public var availableZoomPresets: [CGFloat] = [0.5, 1.0, 2.0]

    public let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "com.tracecam.camera.sessionQueue")

    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    override private init() {
        super.init()
        checkAuthorization()
    }

    public func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
                self.hasCameraPermissionDenied = false
            }
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    self.hasCameraPermissionDenied = !granted
                    if granted {
                        self.setupSession()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.hasCameraPermissionDenied = true
            }
        @unknown default:
            break
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            // Discover best device (triple, dual wide, or standard wide angle)
            let deviceTypes: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInWideAngleCamera
            ]
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: .back
            )

            guard let device = discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.session.commitConfiguration()
                return
            }
            self.videoDevice = device

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoDeviceInput = input
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                self.session.commitConfiguration()

                // Check min/max zoom capabilities
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = min(device.maxAvailableVideoZoomFactor, 5.0)
                DispatchQueue.main.async {
                    var presets: [CGFloat] = []
                    if minZoom <= 0.5 { presets.append(0.5) }
                    presets.append(1.0)
                    if maxZoom >= 2.0 { presets.append(2.0) }
                    self.availableZoomPresets = presets.isEmpty ? [1.0] : presets
                }

                self.startSession()
            } catch {
                print("TraceCam: Error setting up camera device input: \(error.localizedDescription)")
                self.session.commitConfiguration()
            }
        }
    }

    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = self.session.isRunning
                }
            }
        }
    }

    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.isTorchOn = false
                }
            }
        }
    }

    public func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                let clampedZoom = max(device.minAvailableVideoZoomFactor, min(factor, device.maxAvailableVideoZoomFactor))
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.currentZoom = clampedZoom
                }
            } catch {
                print("TraceCam: Failed to set camera zoom: \(error)")
            }
        }
    }

    public func toggleTorch() {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.videoDevice, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                let newTorchState = device.torchMode != .on
                device.torchMode = newTorchState ? .on : .off
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.isTorchOn = newTorchState
                }
            } catch {
                print("TraceCam: Failed to toggle torch: \(error)")
            }
        }
    }

    /// Captures a live frame from the camera.
    public func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.photoContinuation = continuation
            sessionQueue.async {
                let settings = AVCapturePhotoSettings()
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("TraceCam: Photo capture error: \(error)")
            photoContinuation?.resume(returning: nil)
            photoContinuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(returning: nil)
            photoContinuation = nil
            return
        }

        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}
