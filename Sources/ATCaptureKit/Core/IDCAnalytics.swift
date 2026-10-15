import Foundation

/// Implemented by the host app to forward Identity Capture events to its analytics pipeline.
public protocol IDCAnalyticsReporting: AnyObject {
    func report(event name: String, parameters: [String: Any?])
}

public enum IDCAnalytics {

    /// Set once by the host at launch. Events are dropped while it is `nil`.
    public nonisolated(unsafe) static weak var reporter: IDCAnalyticsReporting?

    private enum EventName {
        static let flowStarted = "identity_capture_started"
        static let pieceCaptured = "identity_capture_piece_captured"
        static let pieceVerified = "identity_capture_piece_verified"
        static let pieceRejected = "identity_capture_piece_rejected"
        static let flowCompleted = "identity_capture_completed"
        static let flowExited = "identity_capture_exited"
    }

    static func flowStarted(context: String, pieces: [IDCPiece]) {
        log(EventName.flowStarted, ["pieces": pieces.map(\.rawValue).joined(separator: ",")], context: context)
    }

    static func pieceCaptured(context: String, piece: IDCPiece, source: IDCCaptureSource) {
        log(EventName.pieceCaptured, [
            "piece": piece.rawValue,
            "mode": source == .liveScan ? "live" : "camera_roll",
        ], context: context)
    }

    static func pieceVerified(context: String, piece: IDCPiece) {
        log(EventName.pieceVerified, ["piece": piece.rawValue], context: context)
    }

    static func pieceRejected(context: String, piece: IDCPiece, reason: String) {
        log(EventName.pieceRejected, ["piece": piece.rawValue, "reason": reason], context: context)
    }

    static func flowCompleted(context: String) {
        log(EventName.flowCompleted, [:], context: context)
    }

    static func flowExited(context: String, at phase: String) {
        log(EventName.flowExited, ["phase": phase], context: context)
    }

    private static func log(_ name: String, _ params: [String: Any?], context: String) {
        var merged = params
        merged["host_context"] = context
        reporter?.report(event: name, parameters: merged)
    }
}
