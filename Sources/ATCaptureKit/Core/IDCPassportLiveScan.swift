import AVFoundation
import UIKit

@MainActor
final class IDCPassportLiveScan: ObservableObject {

    @Published private(set) var guidance: IDCPassportGuidance = .searching
    @Published private(set) var isGoodFrame = false
    @Published private(set) var isProcessing = false
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var capturedFieldDetections: IDCFieldDetections?
    @Published private(set) var hasSeenPassport = false

    nonisolated private static let goodFramesRequired = 10
    nonisolated private static let guideBox = CGRect(x: 0.025, y: 0.313, width: 0.95, height: 0.374)
    nonisolated private static let enterMinRatio: CGFloat = 0.78
    nonisolated private static let enterMaxRatio: CGFloat = 0.82
    nonisolated private static let exitMinRatio: CGFloat = 0.73
    nonisolated private static let tooCloseCoverage: CGFloat = 0.85
    nonisolated private static let overexposedBrightness: Float = 0.7
    nonisolated private static let messageHoldInterval: TimeInterval = 0.4

    nonisolated(unsafe) private let analyzer: IDCPassportAnalyzer
    nonisolated(unsafe) private var isForBackPage = false
    nonisolated(unsafe) private var hasReportedSeen = false
    nonisolated(unsafe) private var passportIdentified = false
    nonisolated(unsafe) private var allowFrameProcessing = false
    nonisolated(unsafe) private var lastPassportFrame: CVPixelBuffer?
    nonisolated(unsafe) private var lastPassportRect: CGRect?
    nonisolated(unsafe) private var lastPassportFieldDetections: IDCFieldDetections?
    nonisolated(unsafe) private var lastPassportSharpness: Float = 0
    nonisolated(unsafe) private var goodFramesCount = 0
    nonisolated(unsafe) private var isCapturing = false
    nonisolated(unsafe) private var currentGuidance: IDCPassportGuidance = .searching
    nonisolated(unsafe) private var currentRankDate = Date()
    nonisolated(unsafe) private var currentRank = 7

    init(analyzer: IDCPassportAnalyzer) {
        self.analyzer = analyzer
    }

    func start(isForBackPage: Bool) {
        capturedImage = nil
        isProcessing = false
        isGoodFrame = false
        guidance = .searching
        self.isForBackPage = isForBackPage
        lastPassportFrame = nil
        lastPassportRect = nil
        lastPassportFieldDetections = nil
        lastPassportSharpness = 0
        goodFramesCount = 0
        isCapturing = false
        currentGuidance = .searching
        currentRankDate = Date()
        currentRank = 7
        passportIdentified = false
        allowFrameProcessing = true
    }

    func stop() {
        allowFrameProcessing = false
    }

    nonisolated func process(_ sampleBuffer: CMSampleBuffer) {
        guard allowFrameProcessing else { return }
        let frame = IDCCameraFrame(sampleBuffer: sampleBuffer, isFrontCamera: false, viewfinderSize: .zero)
        guard let pixelBuffer = frame.pixelBuffer,
              let analysis = analyzer.analyzeFrame(frame, isForBackPage: isForBackPage) else { return }

        let detection: IDCPassportDetection
        switch analysis {
        case .failed:
            handleBadFrame(.searching, rank: 7)
            return
        case .noPassport(let wrongPageInFrame):
            passportIdentified = false
            if wrongPageInFrame {
                handleBadFrame(.wrongPage, rank: 3)
            } else {
                handleBadFrame(.searching, rank: 6)
            }
            return
        case .passport(let found):
            detection = found
        }

        reportPassportSeenIfNeeded()

        if detection.isTravelDocument {
            passportIdentified = false
            handleBadFrame(.travelDoc, rank: 3)
            return
        }

        if !isForBackPage && !detection.isMRZVisible {
            passportIdentified = false
            handleBadFrame(.searching, rank: 6)
            return
        }

        switch evaluateFit(detection.bounds) {
        case .tooFar:
            handleBadFrame(.moveCloser, rank: 4)
            return
        case .tooClose:
            handleBadFrame(.tooClose, rank: 4)
            return
        case .outOfBox:
            handleBadFrame(.outOfBox, rank: 5)
            return
        case .good:
            break
        }

        if detection.hasFingers {
            handleBadFrame(.fingers, rank: 2)
            return
        }

        if detection.hasGlare {
            let brightness = analyzer.frameQuality(frame).brightness
            handleBadFrame(brightness > Self.overexposedBrightness ? .lightReflection : .glare, rank: 3)
            return
        }

        goodFramesCount += 1
        let sharpness = analyzer.frameQuality(frame).sharpness
        if sharpness >= lastPassportSharpness {
            lastPassportSharpness = sharpness
            lastPassportFrame = pixelBuffer
            lastPassportRect = detection.bounds
            lastPassportFieldDetections = detection.fieldDetections
        }

        currentRank = 1
        currentGuidance = .holdStill
        currentRankDate = Date()

        DispatchQueue.main.async { [weak self] in
            self?.guidance = .holdStill
            self?.isGoodFrame = true
        }

        if goodFramesCount >= Self.goodFramesRequired && !isCapturing {
            isCapturing = true
            allowFrameProcessing = false
            DispatchQueue.main.async { [weak self] in
                self?.captureLastKnownBestFrame()
            }
        }
    }

    nonisolated private func reportPassportSeenIfNeeded() {
        guard !hasReportedSeen else { return }
        hasReportedSeen = true
        DispatchQueue.main.async { [weak self] in self?.hasSeenPassport = true }
    }

    nonisolated private func handleBadFrame(_ guidance: IDCPassportGuidance, rank: Int) {
        if rank <= currentRank || Date().timeIntervalSince(currentRankDate) >= Self.messageHoldInterval {
            currentRank = rank
            currentGuidance = guidance
            currentRankDate = Date()
        }

        goodFramesCount = 0
        isCapturing = false
        lastPassportFrame = nil
        lastPassportSharpness = 0
        lastPassportRect = nil
        lastPassportFieldDetections = nil

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.guidance = self.currentGuidance
            self.isGoodFrame = false
        }
    }

    private enum FitResult {
        case tooFar, tooClose, outOfBox, good
    }

    nonisolated private func evaluateFit(_ detected: CGRect) -> FitResult {
        let guide = Self.guideBox

        if !guide.contains(detected) && !detected.contains(guide) {
            passportIdentified = false
            let intersection = guide.intersection(detected)
            let intersectionArea = intersection.isNull ? 0 : intersection.width * intersection.height
            let coverage = intersectionArea / (guide.width * guide.height)
            return coverage > Self.tooCloseCoverage ? .tooClose : .outOfBox
        }

        if detected.contains(guide) {
            passportIdentified = false
            return .tooClose
        }

        let ratioWidth = detected.width / guide.width
        let ratioHeight = detected.height / guide.height

        if !passportIdentified {
            if ratioWidth < Self.enterMinRatio && ratioHeight < Self.enterMinRatio {
                return .tooFar
            } else if ratioWidth > Self.enterMaxRatio && ratioHeight > Self.enterMaxRatio {
                return .tooClose
            }
            passportIdentified = true
            return .good
        }

        if ratioWidth < Self.exitMinRatio && ratioHeight < Self.exitMinRatio {
            passportIdentified = false
            return .tooFar
        }
        return .good
    }

    private func captureLastKnownBestFrame() {
        isProcessing = true

        nonisolated(unsafe) let pixelBuffer = lastPassportFrame
        let normalizedRect = lastPassportRect
        let fieldDetections = lastPassportFieldDetections

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let pixelBuffer,
                  let normalizedRect,
                  let capture = IDCFrameRenderer.passportCapture(pixelBuffer, normalizedRect: normalizedRect) else {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    self?.allowFrameProcessing = true
                    self?.isCapturing = false
                }
                return
            }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isProcessing = false
                self.capturedFieldDetections = capture.isCropped ? fieldDetections : nil
                self.capturedImage = capture.image
                IDCCaptureSound.play()
            }
        }
    }
}
