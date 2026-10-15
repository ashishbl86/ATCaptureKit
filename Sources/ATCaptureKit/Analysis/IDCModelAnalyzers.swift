import CoreMotion
import UIKit

@MainActor
struct IDCModelAnalyzerProvider: IDCAnalyzerProvider {
    private let runner: IDCModelRunner?
    private let passportChecks: IDCPassportChecks
    private let selfieChecks: IDCSelfieChecks
    private let selfieUploadChecks: IDCSelfieChecks

    init(configuration: IDCConfiguration, runner: IDCModelRunner?) {
        self.runner = runner
        passportChecks = configuration.passportChecks
        selfieChecks = configuration.selfieChecks
        selfieUploadChecks = configuration.selfieUploadChecks ?? configuration.selfieChecks
    }

    func makePassportAnalyzer() -> IDCPassportAnalyzer {
        IDCModelPassportAnalyzer(runner: runner, checks: passportChecks)
    }

    func makeSelfieAnalyzer() -> IDCSelfieAnalyzer {
        IDCModelSelfieAnalyzer(runner: runner, liveChecks: selfieChecks, uploadChecks: selfieUploadChecks)
    }
}

enum IDCModelReadiness {
    static func wait(until isReady: @escaping @Sendable () -> Bool, timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !isReady() {
            if Date() >= deadline { return false }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return true
    }
}

final class IDCModelPassportAnalyzer: IDCPassportAnalyzer {
    private let runner: IDCModelRunner?
    private let checks: IDCPassportChecks
    nonisolated(unsafe) private var inference: IDCPassportInference?

    init(runner: IDCModelRunner?, checks: IDCPassportChecks) {
        self.runner = runner
        self.checks = checks
    }

    @MainActor
    func prepare() {
        guard inference == nil else { return }
        inference = IDCPassportInference(runner: runner)
    }

    nonisolated func analyzeFrame(_ frame: IDCCameraFrame, isForBackPage: Bool) -> IDCPassportAnalysis? {
        guard let inference, inference.isReady, let pixelBuffer = frame.pixelBuffer else { return nil }
        do {
            return try inference.analyze(pixelBuffer, rotationDegrees: 90, isForBackPage: isForBackPage, checks: checks)
        } catch {
            return .failed
        }
    }

    nonisolated func frameQuality(_ frame: IDCCameraFrame) -> IDCFrameQuality {
        guard let pixelBuffer = frame.pixelBuffer else { return IDCFrameQuality(brightness: 0, sharpness: 0) }
        let measured = IDCPixelBuffers.meanAndVariance(of: pixelBuffer)
        return IDCFrameQuality(brightness: measured.mean, sharpness: measured.variance)
    }

    @MainActor
    func analyzePhoto(_ image: UIImage, isForBackPage: Bool) async -> IDCPassportAnalysis? {
        prepare()
        guard let inference else { return nil }
        guard await IDCModelReadiness.wait(until: { inference.isReady }) else { return nil }

        let checks = self.checks
        return await Task.detached {
            do {
                return try inference.analyze(image, isForBackPage: isForBackPage, checks: checks)
            } catch {
                return .failed
            }
        }.value
    }
}

final class IDCModelSelfieAnalyzer: IDCSelfieAnalyzer {
    private let runner: IDCModelRunner?
    private let liveChecks: IDCSelfieChecks
    private let uploadChecks: IDCSelfieChecks
    private let motionManager = CMMotionManager()
    nonisolated(unsafe) private var inference: IDCSelfieInference?
    private var documentInference: IDCPassportInference?

    init(runner: IDCModelRunner?, liveChecks: IDCSelfieChecks, uploadChecks: IDCSelfieChecks) {
        self.runner = runner
        self.liveChecks = liveChecks
        self.uploadChecks = uploadChecks
    }

    @MainActor
    func prepare() {
        guard inference == nil else { return }
        inference = IDCSelfieInference(runner: runner, liveChecks: liveChecks, uploadChecks: uploadChecks)
    }

    @MainActor
    func liveAnalysisWillStart() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates()
    }

    @MainActor
    func liveAnalysisDidStop() {
        motionManager.stopDeviceMotionUpdates()
    }

    nonisolated func analyzeFrame(_ frame: IDCCameraFrame) -> IDCSelfieAnalysis? {
        guard let inference, inference.isReady, let pixelBuffer = frame.pixelBuffer else { return nil }
        let inspection = inference.inspect(
            .liveFrame(pixelBuffer, isFrontCamera: frame.isFrontCamera, viewfinderBounds: CGRect(origin: .zero, size: frame.viewfinderSize)),
            deviceMotion: motionManager.deviceMotion
        )
        return IDCSelfieAnalysis(
            guidance: inspection.messages.first ?? .autoCapturing,
            sharpness: inspection.variance,
            faceRects: inspection.faceRects
        )
    }

    @MainActor
    func analyzePhoto(_ image: UIImage) async -> IDCSelfiePhotoAnalysis? {
        prepare()
        guard let inference else { return nil }
        let documentInference = documentInference ?? IDCPassportInference(runner: runner)
        self.documentInference = documentInference

        guard await IDCModelReadiness.wait(until: { inference.isReady }) else { return nil }
        let documentReady = await IDCModelReadiness.wait(until: { documentInference.isReady })

        return await Task.detached {
            if documentReady, Self.looksLikeDocument(image, inference: documentInference) {
                return .document
            }
            let inspection = inference.inspect(.upload(image), deviceMotion: nil)
            return .analyzed(inspection.messages.first ?? .autoCapturing)
        }.value
    }

    nonisolated private static func looksLikeDocument(_ image: UIImage, inference: IDCPassportInference) -> Bool {
        guard let pixelBuffer = IDCPixelBuffers.make(from: image) else { return false }
        let analysis = try? inference.analyze(
            pixelBuffer,
            rotationDegrees: IDCPixelBuffers.rotationDegrees(of: image),
            isForBackPage: false,
            checks: IDCPassportChecks()
        )
        switch analysis {
        case .passport, .noPassport(wrongPageInFrame: true):
            return true
        default:
            return false
        }
    }
}
