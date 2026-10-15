import AVFoundation
import SwiftUI
import UIKit

// MARK: - Value types

/// Field boxes the passport model detected (photo / signature / MRZ), normalized to the cropped passport image.
/// `nil` means "not detected"; the detection art then falls back to its static placement.
public struct IDCFieldDetections {
    public let photo: CGRect?
    public let signature: CGRect?
    public let mrz: CGRect?

    public init(photo: CGRect? = nil, signature: CGRect? = nil, mrz: CGRect? = nil) {
        self.photo = photo
        self.signature = signature
        self.mrz = mrz
    }

    var hasAny: Bool { photo != nil || signature != nil || mrz != nil }
}

public enum IDCPassportGuidance {
    case searching
    case moveCloser
    case tooClose
    case outOfBox
    case fingers
    case glare
    case lightReflection
    case travelDoc
    case wrongPage
    case holdStill
}

// MARK: - Live scan state

/// What the passport screen reads while the camera runs. The engine writes it; the screen only observes.
@MainActor
public final class IDCPassportScanState: ObservableObject {
    @Published public var guidance: IDCPassportGuidance = .searching
    @Published public var isGoodFrame = false
    @Published public var isProcessing = false
    @Published public var capturedImage: UIImage?
    /// Set before `capturedImage`, so a `$capturedImage` observer can read it.
    @Published public var capturedFieldDetections: IDCFieldDetections?
    @Published public var hasSeenPassport = false
}

@MainActor
public final class IDCSelfieScanState: ObservableObject {
    @Published public var statusMessage = ""
    @Published public var countdownNumber: Int?
    @Published public var isGoodFrame = false
    @Published public var isProcessing = false
    @Published public var captureProgress: Double = 0
    @Published public var capturedImage: UIImage?
    @Published public var hasSeenFace = false
}

// MARK: - Engines

/// On-device passport analysis. One engine serves the live scan and the gallery-upload check, so the
/// detection model loads once. The app owns the implementation (Vision / TFLite).
public protocol IDCPassportScanEngine: AnyObject {
    @MainActor func prepare()

    @MainActor func validateUpload(
        _ image: UIImage,
        isForBackPage: Bool,
        completion: @escaping (_ cropped: UIImage?, _ fieldDetections: IDCFieldDetections?, _ failure: IDCCaptureFailure?) -> Void
    )

    /// Resets and starts live analysis, publishing results into `state`.
    @MainActor func startLive(isForBackPage: Bool, state: IDCPassportScanState)
    @MainActor func stopLive()

    /// Called on the camera's video queue.
    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer)
}

public protocol IDCSelfieScanEngine: AnyObject {
    @MainActor func prepare()

    @MainActor func validateUpload(_ image: UIImage, completion: @escaping (_ failure: IDCCaptureFailure?) -> Void)

    /// Resets and starts live analysis, publishing results into `state`.
    @MainActor func startLive(isFrontCamera: Bool, state: IDCSelfieScanState)
    /// Restarts analysis after the camera flips.
    @MainActor func restartLive(isFrontCamera: Bool)
    @MainActor func stopLive()

    /// The preview view the analyzer maps face rects against.
    @MainActor var viewFinderView: UIView? { get set }

    /// Called on the camera's video queue.
    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer)
}

/// Supplied by the host app. Each scan screen asks for its own engine.
@MainActor
public protocol IDCScanEngineProvider {
    func makePassportEngine() -> IDCPassportScanEngine
    func makeSelfieEngine() -> IDCSelfieScanEngine
}

/// Keeps an engine alive for the life of a screen (`@StateObject` evaluates its initializer once).
@MainActor
final class IDCScanEngineHolder<Engine>: ObservableObject {
    let engine: Engine
    init(_ engine: Engine) { self.engine = engine }
}
