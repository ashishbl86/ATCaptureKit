import ATCaptureKit
import AVFoundation
import Combine
import UIKit

struct VDCCaptureScanEngines: IDCScanEngineProvider {
    private let ocrSettings: PassportOcrSettings?
    private let selfieLiveCaptureSettings: SelfieCaptureSettings?
    private let selfieUploadCaptureSettings: SelfieCaptureSettings?

    nonisolated init(
        ocrSettings: PassportOcrSettings? = nil,
        selfieLiveCaptureSettings: SelfieCaptureSettings? = nil,
        selfieUploadCaptureSettings: SelfieCaptureSettings? = nil
    ) {
        self.ocrSettings = ocrSettings
        self.selfieLiveCaptureSettings = selfieLiveCaptureSettings
        self.selfieUploadCaptureSettings = selfieUploadCaptureSettings
    }

    func makePassportEngine() -> IDCPassportScanEngine {
        VDCPassportScanEngine(ocrSettings: ocrSettings)
    }

    func makeSelfieEngine() -> IDCSelfieScanEngine {
        VDCSelfieScanEngine(
            liveCaptureSettings: selfieLiveCaptureSettings,
            uploadCaptureSettings: selfieUploadCaptureSettings
        )
    }
}

final class VDCPassportScanEngine: IDCPassportScanEngine {
    private let uploadAnalyzer: PassportUploadAnalyzer
    private let ocrSettings: PassportOcrSettings?
    nonisolated(unsafe) private var processor: PassportFrameProcessor?
    private var bindings = Set<AnyCancellable>()

    @MainActor
    init(ocrSettings: PassportOcrSettings?) {
        self.ocrSettings = ocrSettings
        uploadAnalyzer = PassportUploadAnalyzer(ocrSettings: ocrSettings)
    }

    @MainActor
    func prepare() {
        uploadAnalyzer.prepare()
    }

    @MainActor
    func validateUpload(
        _ image: UIImage,
        isForBackPage: Bool,
        completion: @escaping (UIImage?, IDCFieldDetections?, IDCCaptureFailure?) -> Void
    ) {
        uploadAnalyzer.validate(image, isForBackPage: isForBackPage) { result in
            completion(result.cropped, result.fieldDetections.map(IDCFieldDetections.init), result.failure?.idcFailure)
        }
    }

    @MainActor
    func startLive(isForBackPage: Bool, state: IDCPassportScanState) {
        stopLive()
        let processor = PassportFrameProcessor()
        processor.restart(isBack: isForBackPage)
        processor.ocrSettings = ocrSettings
        processor.prepare(reusing: uploadAnalyzer.analyzer)
        bind(processor, to: state)
        self.processor = processor
    }

    @MainActor
    func stopLive() {
        processor?.stop()
        processor = nil
        bindings.removeAll()
    }

    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        processor?.processFrame(sampleBuffer)
    }

    @MainActor
    private func bind(_ processor: PassportFrameProcessor, to state: IDCPassportScanState) {
        processor.$guidance
            .sink { [weak state] in state?.guidance = IDCPassportGuidance($0) }
            .store(in: &bindings)
        processor.$isGoodFrame
            .sink { [weak state] in state?.isGoodFrame = $0 }
            .store(in: &bindings)
        processor.$isProcessing
            .sink { [weak state] in state?.isProcessing = $0 }
            .store(in: &bindings)
        processor.$hasSeenPassport
            .sink { [weak state] in state?.hasSeenPassport = $0 }
            .store(in: &bindings)
        processor.$capturedFieldDetections
            .sink { [weak state] in state?.capturedFieldDetections = $0.map(IDCFieldDetections.init) }
            .store(in: &bindings)
        processor.$capturedImage
            .sink { [weak state] in state?.capturedImage = $0 }
            .store(in: &bindings)
    }
}

final class VDCSelfieScanEngine: IDCSelfieScanEngine {
    private let uploadAnalyzer: SelfieUploadAnalyzer
    nonisolated(unsafe) private var processor: SelfieFrameProcessor?
    private var bindings = Set<AnyCancellable>()
    private var finderView: UIView?

    @MainActor
    init(liveCaptureSettings: SelfieCaptureSettings?, uploadCaptureSettings: SelfieCaptureSettings?) {
        uploadAnalyzer = SelfieUploadAnalyzer(
            liveCaptureSettings: liveCaptureSettings,
            uploadCaptureSettings: uploadCaptureSettings
        )
    }

    @MainActor
    var viewFinderView: UIView? {
        get { finderView }
        set {
            finderView = newValue
            processor?.viewFinderView = newValue
        }
    }

    @MainActor
    func prepare() {
        uploadAnalyzer.prepare()
    }

    @MainActor
    func validateUpload(_ image: UIImage, completion: @escaping (IDCCaptureFailure?) -> Void) {
        uploadAnalyzer.validate(image) { result in
            completion(result.failure?.idcFailure)
        }
    }

    @MainActor
    func startLive(isFrontCamera: Bool, state: IDCSelfieScanState) {
        stopLive()
        let processor = SelfieFrameProcessor()
        processor.prepare(reusing: uploadAnalyzer.analyzer)
        processor.isFrontCamera = isFrontCamera
        processor.viewFinderView = finderView
        bind(processor, to: state)
        self.processor = processor
    }

    @MainActor
    func restartLive(isFrontCamera: Bool) {
        processor?.restart()
        processor?.isFrontCamera = isFrontCamera
    }

    @MainActor
    func stopLive() {
        processor?.stop()
        processor = nil
        bindings.removeAll()
    }

    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        processor?.processFrame(sampleBuffer)
    }

    @MainActor
    private func bind(_ processor: SelfieFrameProcessor, to state: IDCSelfieScanState) {
        processor.$statusMessage
            .sink { [weak state] in state?.statusMessage = $0 }
            .store(in: &bindings)
        processor.$countdownNumber
            .sink { [weak state] in state?.countdownNumber = $0 }
            .store(in: &bindings)
        processor.$isGoodFrame
            .sink { [weak state] in state?.isGoodFrame = $0 }
            .store(in: &bindings)
        processor.$isProcessing
            .sink { [weak state] in state?.isProcessing = $0 }
            .store(in: &bindings)
        processor.$captureProgress
            .sink { [weak state] in state?.captureProgress = $0 }
            .store(in: &bindings)
        processor.$hasSeenFace
            .sink { [weak state] in state?.hasSeenFace = $0 }
            .store(in: &bindings)
        processor.$capturedImage
            .sink { [weak state] in state?.capturedImage = $0 }
            .store(in: &bindings)
    }
}

extension IDCPassportGuidance {
    init(_ guidance: PassportScanGuidance) {
        switch guidance {
        case .searching: self = .searching
        case .moveCloser: self = .moveCloser
        case .tooClose: self = .tooClose
        case .outOfBox: self = .outOfBox
        case .fingers: self = .fingers
        case .glare: self = .glare
        case .lightReflection: self = .lightReflection
        case .travelDoc: self = .travelDoc
        case .wrongPage: self = .wrongPage
        case .holdStill: self = .holdStill
        }
    }
}

extension IDCFieldDetections {
    init(_ detections: PassportFieldDetections) {
        self.init(photo: detections.photo, signature: detections.signature, mrz: detections.mrz)
    }
}

extension PassportFieldDetections {
    init(_ detections: IDCFieldDetections) {
        photo = detections.photo
        signature = detections.signature
        mrz = detections.mrz
    }
}

extension PassportUploadValidationFailure {
    var idcFailure: IDCCaptureFailure {
        switch self {
        case .scannerNotReady: return .scannerNotReady
        case .travelDocument: return .travelDocument
        case .textHardToRead: return .textHardToRead
        case .fingersOnDocument: return .fingersOnDocument
        case .lightReflection: return .lightReflection
        case .invalidPassportBack: return .invalidPassportBack
        case .invalidPassport: return .invalidPassport
        case .unreadablePhoto: return .unreadablePhoto
        }
    }
}

extension SelfieUploadValidationFailure {
    var idcFailure: IDCCaptureFailure {
        switch self {
        case .scannerNotReady: return .scannerNotReady
        case .notASelfie: return .notASelfie
        case .qualityIssue(let issue): return .selfieIssue(issue)
        }
    }
}
