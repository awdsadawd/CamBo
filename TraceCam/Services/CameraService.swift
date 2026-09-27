import Foundation
import AVFoundation
import UIKit
import Combine

/// Represents a user-facing zoom preset with its actual hardware zoom factor.
public struct CameraZoomPreset: Identifiable, Equatable, Hashable {
    public let id: String
    public let label: String
    public let deviceFactor: CGFloat

    public init(label: String, deviceFactor: CGFloat) {
        self.id = label
        self.label = label
        self.deviceFactor = deviceFactor
    }
}

/// Manages AVFoundation camera capture session, device zoom with proper lens switching, torch, and photo capture.
public final class CameraService: NSObject, ObservableObject {
    public static let shared = CameraService()

    @Published public var isRunning: Bool = false
    @Published public var isTorchOn: Bool = false
    @Published public var isAuthorized: Bool = false
    @Published public var hasCameraPermissionDenied: Bool = false

    /// Available zoom presets mapped to actual device hardware lens factors.
    @Published public var zoomPresets: [CameraZoomPreset] = [
        CameraZoomPreset(label: "1.0x", deviceFactor: 1.0)
    ]
    @Published public var activePreset: CameraZoomPreset = CameraZoomPreset(label: "1.0x", deviceFactor: 1.0)

    public let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "com.tracecam.camera.sessionQueue")

    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    override private init() {
        super.init()
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

            if self.session.isRunning { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            // Discover best multi-lens device for proper optical zoom switching.
            // Priority: triple > dual wide > wide only
            let deviceTypes: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: .back
            )

            guard let device = discovery.devices.first
                    ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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

                // Build zoom presets from the virtual device's actual switchover points.
                let presets = self.buildZoomPresets(for: device)

                DispatchQueue.main.async {
                    self.zoomPresets = presets
                    // Default to the "1.0x" preset (standard wide lens)
                    if let defaultPreset = presets.first(where: { $0.label == "1.0x" }) {
                        self.activePreset = defaultPreset
                    } else if let first = presets.first {
                        self.activePreset = first
                    }
                }

                // Apply the default 1x zoom on session start
                if let defaultPreset = presets.first(where: { $0.label == "1.0x" }) {
                    try device.lockForConfiguration()
                    device.videoZoomFactor = defaultPreset.deviceFactor
                    device.unlockForConfiguration()
                }

                self.startSession()
            } catch {
                print("TraceCam: Error setting up camera device input: \(error.localizedDescription)")
                self.session.commitConfiguration()
            }
        }
    }

    /// Maps virtual device lens switchover points to user-facing 0.5x / 1.0x / 2.0x labels.
    ///
    /// For iPhone 11 (builtInDualWideCamera):
    ///   - virtualDeviceSwitchOverVideoZoomFactors = [2.0]
    ///   - device factor 1.0 = ultra-wide lens (13mm) → UI label "0.5x"
    ///   - device factor 2.0 = wide lens (26mm)       → UI label "1.0x"
    ///   - device factor 4.0 = 2x digital on wide     → UI label "2.0x"
    ///
    /// For iPhone 11 Pro (builtInTripleCamera):
    ///   - switchOvers = [2.0, 6.0]
    ///   - device factor 1.0  = ultra-wide → "0.5x"
    ///   - device factor 2.0  = wide       → "1.0x"
    ///   - device factor 6.0  = telephoto  → "3.0x"
    ///
    /// For single-lens iPhones (builtInWideAngleCamera):
    ///   - No switchovers
    ///   - device factor 1.0 = wide → "1.0x"
    ///   - device factor 2.0 = 2x digital → "2.0x"
    private func buildZoomPresets(for device: AVCaptureDevice) -> [CameraZoomPreset] {
        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        let maxZoom = min(device.maxAvailableVideoZoomFactor, 10.0)

        if switchOvers.isEmpty {
            // Single-lens camera — no optical zoom, just digital
            var presets = [CameraZoomPreset(label: "1.0x", deviceFactor: 1.0)]
            if maxZoom >= 2.0 {
                presets.append(CameraZoomPreset(label: "2.0x", deviceFactor: 2.0))
            }
            return presets
        } else if switchOvers.count == 1 {
            // Dual camera (e.g., iPhone 11 dual wide: ultra-wide + wide)
            let wideAt = switchOvers[0] // typically 2.0
            var presets = [
                CameraZoomPreset(label: "0.5x", deviceFactor: 1.0),           // ultra-wide
                CameraZoomPreset(label: "1.0x", deviceFactor: wideAt),         // wide (optical switch)
            ]
            if maxZoom >= wideAt * 2.0 {
                presets.append(CameraZoomPreset(label: "2.0x", deviceFactor: wideAt * 2.0)) // 2x digital on wide
            }
            return presets
        } else {
            // Triple camera (e.g., iPhone 11 Pro, 12 Pro, 13 Pro, etc.)
            let wideAt = switchOvers[0]  // typically 2.0
            let teleAt = switchOvers[1]  // varies (6.0 on 11 Pro, 3.0 on newer)
            let teleLabel = String(format: "%.0fx", teleAt / wideAt) // "3x" or "2x" depending
            return [
                CameraZoomPreset(label: "0.5x", deviceFactor: 1.0),
                CameraZoomPreset(label: "1.0x", deviceFactor: wideAt),
                CameraZoomPreset(label: "\(teleLabel)", deviceFactor: teleAt),
            ]
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

    /// Sets the camera zoom to a specific preset's device factor, triggering actual lens switches.
    public func applyZoomPreset(_ preset: CameraZoomPreset) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.videoDevice else { return }
            do {
                try device.lockForConfiguration()
                let clampedZoom = max(device.minAvailableVideoZoomFactor,
                                     min(preset.deviceFactor, device.maxAvailableVideoZoomFactor))
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.activePreset = preset
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

    /// Captures a still frame from the camera.
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
