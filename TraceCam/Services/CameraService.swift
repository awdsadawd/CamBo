import Foundation
import AVFoundation
import UIKit
import Combine

/// Represents a user-facing zoom preset pointing to a physical camera lens.
public struct CameraZoomPreset: Identifiable, Equatable, Hashable {
    public let id: String
    public let label: String
    public let deviceId: String

    public init(label: String, deviceId: String) {
        self.id = label
        self.label = label
        self.deviceId = deviceId
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
    @Published public var zoomPresets: [CameraZoomPreset] = []
    @Published public var activePreset: CameraZoomPreset? = nil

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

            // Build zoom presets from PHYSICAL devices to ensure 100% optical clarity
            let presets = self.buildZoomPresets()
            
            guard let defaultPreset = presets.first(where: { $0.label == "1.0x" }) ?? presets.first,
                  let initialDevice = AVCaptureDevice(uniqueID: defaultPreset.deviceId) else {
                self.session.commitConfiguration()
                return
            }

            self.videoDevice = initialDevice

            do {
                let input = try AVCaptureDeviceInput(device: initialDevice)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.videoDeviceInput = input
                }

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }

                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.zoomPresets = presets
                    self.activePreset = defaultPreset
                }

                self.startSession()
            } catch {
                print("TraceCam: Error setting up camera device input: \(error.localizedDescription)")
                self.session.commitConfiguration()
            }
        }
    }

    /// Discovers physical rear cameras and creates 0.5x, 1.0x, 2.0x presets
    private func buildZoomPresets() -> [CameraZoomPreset] {
        var presets: [CameraZoomPreset] = []
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        
        for device in discovery.devices {
            if device.deviceType == .builtInUltraWideCamera {
                presets.append(CameraZoomPreset(label: "0.5x", deviceId: device.uniqueID))
            } else if device.deviceType == .builtInWideAngleCamera {
                presets.append(CameraZoomPreset(label: "1.0x", deviceId: device.uniqueID))
            } else if device.deviceType == .builtInTelephotoCamera {
                presets.append(CameraZoomPreset(label: "2.0x", deviceId: device.uniqueID))
            }
        }
        
        presets.sort { $0.label < $1.label }

        if presets.isEmpty {
            if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                presets.append(CameraZoomPreset(label: "1.0x", deviceId: wide.uniqueID))
            }
        }
        return presets
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

    /// Switches the AV session to use a different physical camera lens.
    public func applyZoomPreset(_ preset: CameraZoomPreset) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard let newDevice = AVCaptureDevice(uniqueID: preset.deviceId) else { return }
            
            self.session.beginConfiguration()
            
            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                    self.videoDevice = newDevice
                }
            } catch {
                print("TraceCam: Failed to switch physical camera lens: \(error)")
            }
            
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.activePreset = preset
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
