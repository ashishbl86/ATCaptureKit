import Foundation

public struct IDCCallbacks {
    var onPieceCaptured: ((IDCCaptureResult) -> Void)?
    var onPieceVerified: ((IDCPiece, Any?) -> Void)?
    var onComplete: (_ results: [IDCPiece: IDCCaptureResult], _ payloads: [IDCPiece: Any]) -> Void
    var onExit: () -> Void
    var onSkip: (() -> Void)?
    var onSubjectDetected: ((IDCPiece) -> Void)?

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
