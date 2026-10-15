import Foundation

public protocol IDCVerifier {
    func verify(_ result: IDCCaptureResult) async -> IDCVerificationOutcome
}

struct IDCPassThroughVerifier: IDCVerifier {
    func verify(_ result: IDCCaptureResult) async -> IDCVerificationOutcome {
        .verified(payload: nil)
    }
}

@MainActor
final class IDCMockVerifier: IDCVerifier {

    enum Mode {
        case alwaysVerify
        case rejectFirst(count: Int, reason: String)
        case alwaysReject(reason: String)
        case transportFail(message: String)
    }

    private let mode: Mode
    private let delay: TimeInterval
    private var attempts: [IDCPiece: Int] = [:]

    init(mode: Mode = .alwaysVerify, delay: TimeInterval = 1.5) {
        self.mode = mode
        self.delay = delay
    }

    func verify(_ result: IDCCaptureResult) async -> IDCVerificationOutcome {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        attempts[result.piece, default: 0] += 1
        switch mode {
        case .alwaysVerify:
            return .verified
        case .rejectFirst(let count, let reason):
            return attempts[result.piece, default: 0] <= count ? .rejected(reason: reason) : .verified
        case .alwaysReject(let reason):
            return .rejected(reason: reason)
        case .transportFail(let message):
            return .failed(message: message)
        }
    }
}
