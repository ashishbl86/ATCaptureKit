import Foundation

public struct IDCCallbacks {
    public var onPieceCaptured: ((IDCCaptureResult) -> Void)?
    public var onPieceVerified: ((IDCPiece, Any?) -> Void)?
    public var onComplete: (_ results: [IDCPiece: IDCCaptureResult], _ payloads: [IDCPiece: Any]) -> Void
    public var onExit: () -> Void
    public var onSkip: (() -> Void)?
    public var onSubjectDetected: ((IDCPiece) -> Void)?

    public init(
        onPieceCaptured: ((IDCCaptureResult) -> Void)? = nil,
        onPieceVerified: ((IDCPiece, Any?) -> Void)? = nil,
        onComplete: @escaping (_ results: [IDCPiece: IDCCaptureResult], _ payloads: [IDCPiece: Any]) -> Void,
        onExit: @escaping () -> Void = {},
        onSkip: (() -> Void)? = nil,
        onSubjectDetected: ((IDCPiece) -> Void)? = nil
    ) {
        self.onPieceCaptured = onPieceCaptured
        self.onPieceVerified = onPieceVerified
        self.onComplete = onComplete
        self.onExit = onExit
        self.onSkip = onSkip
        self.onSubjectDetected = onSubjectDetected
    }
}
