import AVFoundation
import UIKit

@MainActor
final class IDCSelfieLiveScan: ObservableObject {

    @Published private(set) var guidance: IDCSelfieGuidance? = .autoCapturing
    @Published private(set) var countdownNumber: Int?
    @Published private(set) var isGoodFrame = false
    @Published private(set) var isProcessing = false
    @Published private(set) var captureProgress: Double = 0
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var hasSeenFace = false

    nonisolated private static let messageHoldInterval: TimeInterval = 0.4
    nonisolated private static let countdownDuration: TimeInterval = 3
    nonisolated private static let countdownTickInterval: TimeInterval = 0.1

    nonisolated(unsafe) private let analyzer: IDCSelfieAnalyzer
    nonisolated(unsafe) private var isFrontCamera = true
    nonisolated(unsafe) private var viewfinderSize: CGSize = .zero
    nonisolated(unsafe) private var hasReportedFaceSeen = false
    nonisolated(unsafe) private var allowFrameProcessing = false
    nonisolated(unsafe) private var lastPixelBuffer: CVPixelBuffer?
    nonisolated(unsafe) private var lastSharpness: Float = 0
    nonisolated(unsafe) private var successAnimationInProgress = false
    nonisolated(unsafe) private var currentGuidance = IDCSelfieGuidance.autoCapturing
    nonisolated(unsafe) private var currentRankDate = Date()
    private var countdownTimer: Timer?

    init(analyzer: IDCSelfieAnalyzer) {
        self.analyzer = analyzer
    }

    func start(isFrontCamera: Bool) {
        reset(isFrontCamera: isFrontCamera)
        analyzer.liveAnalysisWillStart()
    }

    func switchCamera(isFrontCamera: Bool) {
        reset(isFrontCamera: isFrontCamera)
    }

    func stop() {
        allowFrameProcessing = false
        countdownTimer?.invalidate()
        analyzer.liveAnalysisDidStop()
    }

    func updateViewfinderSize(_ size: CGSize) {
        viewfinderSize = size
    }

    private func reset(isFrontCamera: Bool) {
        self.isFrontCamera = isFrontCamera
        capturedImage = nil
        isProcessing = false
        isGoodFrame = false
        countdownNumber = nil
        captureProgress = 0
        guidance = .autoCapturing
        countdownTimer?.invalidate()
        successAnimationInProgress = false
        lastSharpness = 0
        lastPixelBuffer = nil
        currentGuidance = .autoCapturing
        currentRankDate = Date()
        allowFrameProcessing = true
    }

    nonisolated func process(_ sampleBuffer: CMSampleBuffer) {
        guard allowFrameProcessing else { return }
        let viewfinderSize = self.viewfinderSize
        guard viewfinderSize != .zero else { return }
        let frame = IDCCameraFrame(sampleBuffer: sampleBuffer, isFrontCamera: isFrontCamera, viewfinderSize: viewfinderSize)
        guard let analysis = analyzer.analyzeFrame(frame) else { return }

        if !analysis.faceRects.isEmpty { reportFaceSeenIfNeeded() }

        if analysis.guidance.rank <= currentGuidance.rank
            || Date().timeIntervalSince(currentRankDate) >= Self.messageHoldInterval {
            currentGuidance = analysis.guidance
            currentRankDate = Date()
        }

        if currentGuidance != .goodPhoto {
            clearCapturedFrames()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.guidance = self.currentGuidance
                self.countdownNumber = nil
                self.captureProgress = 0
                self.isGoodFrame = false
            }
            return
        }

        guard let pixelBuffer = frame.pixelBuffer else { return }
        if analysis.sharpness >= lastSharpness {
            lastSharpness = analysis.sharpness
            lastPixelBuffer = pixelBuffer
        }

        DispatchQueue.main.async { [weak self] in
            self?.isGoodFrame = true
            self?.guidance = nil
        }

        if !successAnimationInProgress {
            successAnimationInProgress = true
            DispatchQueue.main.async { [weak self] in
                self?.startCountdown()
            }
        }
    }

    nonisolated private func reportFaceSeenIfNeeded() {
        guard !hasReportedFaceSeen else { return }
        hasReportedFaceSeen = true
        DispatchQueue.main.async { [weak self] in self?.hasSeenFace = true }
    }

    nonisolated private func clearCapturedFrames() {
        successAnimationInProgress = false
        lastSharpness = 0
        lastPixelBuffer = nil
        DispatchQueue.main.async { [weak self] in
            self?.countdownTimer?.invalidate()
            self?.countdownNumber = nil
        }
    }

    private func startCountdown() {
        countdownNumber = 3
        countdownTimer?.invalidate()
        let startDate = Date()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: Self.countdownTickInterval, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else {
                    timer.invalidate()
                    return
                }
                let elapsed = Date().timeIntervalSince(startDate)
                self.captureProgress = min(1, elapsed / Self.countdownDuration)
                if elapsed >= Self.countdownDuration {
                    timer.invalidate()
                    self.captureLastKnownBestFrame()
                } else if elapsed >= 2 {
                    self.countdownNumber = 1
                } else if elapsed >= 1 {
                    self.countdownNumber = 2
                }
            }
        }
    }

    private func captureLastKnownBestFrame() {
        allowFrameProcessing = false
        isProcessing = true

        nonisolated(unsafe) let pixelBuffer = lastPixelBuffer
        let viewfinderSize = viewfinderSize

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let pixelBuffer,
                  let image = IDCFrameRenderer.selfieCapture(pixelBuffer, viewfinderSize: viewfinderSize) else {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.allowFrameProcessing = true
                }
                return
            }

            DispatchQueue.main.async {
                self?.isProcessing = false
                self?.capturedImage = image
            }
        }
    }
}
