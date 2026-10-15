import AVFoundation
import UIKit
import SwiftUI
import Combine
import CoreMedia

// MARK: - Video Frame Delegate

final class IDCVideoFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onFrame: (CMSampleBuffer) -> Void

    init(onFrame: @escaping (CMSampleBuffer) -> Void) {
        self.onFrame = onFrame
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrame(sampleBuffer)
    }
}

// MARK: - Camera Service

@MainActor
final class IDCCameraService: NSObject, ObservableObject {

    enum CameraPosition {
        case front
        case back
    }

    @Published var capturedImage: UIImage?
    @Published var isSessionRunning = false
    @Published var isCaptureInProgress = false

    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) var previewView: UIView?

    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "IDCVideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let sessionQueue = DispatchQueue(label: "IDCCameraSessionQueue")
    private var frameDelegate: IDCVideoFrameDelegate?
    private var position: CameraPosition = .back
    private nonisolated(unsafe) var isFrontCamera = false
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private var isConfigured = false

    // MARK: - Photo Mode

    func configure(position: CameraPosition) {
        self.position = position
        self.isFrontCamera = position == .front
        setupSessionAsync(videoMode: false)
    }

    // MARK: - Video Mode

    func configureForVideo(
        position: CameraPosition,
        onFrame: @escaping (CMSampleBuffer) -> Void,
        onConfigured: (@MainActor () -> Void)? = nil
    ) {
        self.position = position
        self.isFrontCamera = position == .front
        frameDelegate = IDCVideoFrameDelegate(onFrame: onFrame)
        setupSessionAsync(videoMode: true, onConfigured: onConfigured)
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    func restartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    func switchVideoCapturePosition(
        to position: CameraPosition,
        onFrame: @escaping (CMSampleBuffer) -> Void
    ) {
        self.position = position
        self.isFrontCamera = position == .front
        frameDelegate = IDCVideoFrameDelegate(onFrame: onFrame)
        let delegate = frameDelegate
        let targetPosition = position

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.setupSession(videoMode: true, position: targetPosition, frameDelegate: delegate)
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    func capturePhoto() async -> UIImage? {
        guard !isCaptureInProgress else { return nil }
        isCaptureInProgress = true

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Private

    private func setupSessionAsync(videoMode: Bool, onConfigured: (@MainActor () -> Void)? = nil) {
        let pos = position
        let delegate = frameDelegate

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setupSession(videoMode: videoMode, position: pos, frameDelegate: delegate)
            guard let onConfigured else { return }
            DispatchQueue.main.async(execute: onConfigured)
        }
    }

    private nonisolated func setupSession(videoMode: Bool, position: CameraPosition, frameDelegate: IDCVideoFrameDelegate?) {
        session.beginConfiguration()

        // Resolution fallback: try high → medium → default
        let presets: [AVCaptureSession.Preset] = [.hd4K3840x2160, .hd1920x1080, .hd1280x720, .photo]
        for preset in presets {
            if session.canSetSessionPreset(preset) {
                session.sessionPreset = preset
                break
            }
        }

        // Remove existing inputs/outputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        // Camera input
        let devicePosition: AVCaptureDevice.Position = position == .front ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if videoMode {
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
                videoDataOutput.alwaysDiscardsLateVideoFrames = true
                videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
                videoDataOutput.setSampleBufferDelegate(frameDelegate, queue: videoDataOutputQueue)
            }
        } else {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
        }

        session.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            self?.isConfigured = true
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension IDCCameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              var image = UIImage(data: data) else {
            Task { @MainActor in
                self.isCaptureInProgress = false
                self.continuation?.resume(returning: nil)
                self.continuation = nil
            }
            return
        }

        // Mirror front camera image
        if isFrontCamera,
           let cgImage = image.cgImage {
            image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        }

        Task { @MainActor in
            self.capturedImage = image
            self.isCaptureInProgress = false
            self.continuation?.resume(returning: image)
            self.continuation = nil
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct IDCCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var onViewCreated: ((IDCCameraPreviewUIView) -> Void)? = nil

    func makeUIView(context: Context) -> IDCCameraPreviewUIView {
        let view = IDCCameraPreviewUIView()
        view.previewLayer.session = session
        onViewCreated?(view)
        return view
    }

    func updateUIView(_ uiView: IDCCameraPreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

final class IDCCameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    // Safe force cast: layerClass is overridden above to return AVCaptureVideoPreviewLayer.
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
