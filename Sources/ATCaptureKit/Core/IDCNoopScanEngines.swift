import AVFoundation
import UIKit

/// Inert engines for previews and the debug harness: live scans never fire and uploads report
/// `.scannerNotReady`. A host app supplies real engines.
@MainActor
struct IDCNoopScanEngineProvider: IDCScanEngineProvider {
    func makePassportEngine() -> IDCPassportScanEngine { IDCNoopPassportScanEngine() }
    func makeSelfieEngine() -> IDCSelfieScanEngine { IDCNoopSelfieScanEngine() }
}

private final class IDCNoopPassportScanEngine: IDCPassportScanEngine {
    func prepare() {}
    func validateUpload(
        _ image: UIImage,
        isForBackPage: Bool,
        completion: @escaping (UIImage?, IDCFieldDetections?, IDCCaptureFailure?) -> Void
    ) {
        completion(nil, nil, .scannerNotReady)
    }
    func startLive(isForBackPage: Bool, state: IDCPassportScanState) {}
    func stopLive() {}
    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {}
}

private final class IDCNoopSelfieScanEngine: IDCSelfieScanEngine {
    var viewFinderView: UIView?
    func prepare() {}
    func validateUpload(_ image: UIImage, completion: @escaping (IDCCaptureFailure?) -> Void) {
        completion(.scannerNotReady)
    }
    func startLive(isFrontCamera: Bool, state: IDCSelfieScanState) {}
    func restartLive(isFrontCamera: Bool) {}
    func stopLive() {}
    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {}
}
