import SwiftUI
import Foundation
import AVFoundation

final class QRScannerViewModel: NSObject, ObservableObject {
    enum PermissionState: Equatable {
        case unknown
        case authorized
        case denied
        case configuring
    }

    struct ScanCapture: Identifiable, Hashable {
        let id = UUID()
        let payload: String
        let symbology: String
        let parsed: ParsedQRContent
        let date: Date
    }

    @Published var permissionState: PermissionState = .unknown
    @Published var lastCapture: ScanCapture?
    @Published var torchEnabled = false
    @Published var isRunning = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "nativeqr.camera.session")
    private var isConfigured = false
    private var videoInput: AVCaptureDeviceInput?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var recentPayloads: [String: Date] = [:]

    func prepareIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
            configureIfNeeded()
        case .notDetermined:
            permissionState = .unknown
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .denied
        }
    }

    func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            permissionState = .authorized
            configureIfNeeded()
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                self.permissionState = granted ? .authorized : .denied
                if granted {
                    self.configureIfNeeded()
                }
            }
        }
    }

    func configureIfNeeded() {
        guard !isConfigured else {
            start()
            return
        }

        permissionState = .configuring
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            defer {
                self.session.commitConfiguration()
            }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                Task { @MainActor in
                    self.permissionState = .denied
                }
                return
            }

            self.session.addInput(input)
            self.videoInput = input

            let output = AVCaptureMetadataOutput()
            guard self.session.canAddOutput(output) else {
                Task { @MainActor in
                    self.permissionState = .denied
                }
                return
            }

            self.session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

            let preferredTypes: [AVMetadataObject.ObjectType] = [
                .qr,
                .aztec,
                .dataMatrix,
                .pdf417,
                .code128,
                .ean8,
                .ean13,
                .upce,
                .code39,
                .code93
            ]
            output.metadataObjectTypes = preferredTypes.filter { output.availableMetadataObjectTypes.contains($0) }
            self.metadataOutput = output
            self.isConfigured = true

            Task { @MainActor in
                self.permissionState = .authorized
                self.start()
            }
        }
    }

    func start() {
        guard permissionState == .authorized else { return }
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in
                self.isRunning = true
            }
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in
                self.isRunning = false
            }
        }
    }

    func resetAndResume() {
        withAnimation(Animation.snappy(duration: 0.3)) {
            lastCapture = nil
        }
        start()
    }

    @MainActor
    func handleImportedPayload(_ payload: String, symbology: String = "Image") {
        let parsed = QRPayloadParser.parse(payload)
        lastCapture = ScanCapture(payload: payload, symbology: symbology, parsed: parsed, date: Date())
        Haptics.shared.success()
    }

    @MainActor
    func toggleTorch() {
        guard let device = videoInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchEnabled ? .off : .on
            device.unlockForConfiguration()
            torchEnabled.toggle()
            Haptics.shared.impact(.light)
        } catch {
            Haptics.shared.warning()
        }
    }
}

extension QRScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let payload = readable.stringValue else {
            return
        }

        Task { @MainActor in
            if let lastSeen = recentPayloads[payload], Date().timeIntervalSince(lastSeen) < 1.5 {
                return
            }
            recentPayloads[payload] = Date()
            let parsed = QRPayloadParser.parse(payload)
            lastCapture = ScanCapture(payload: payload, symbology: readable.type.rawValue, parsed: parsed, date: Date())
            stop()
            Haptics.shared.success()
        }
    }
}
