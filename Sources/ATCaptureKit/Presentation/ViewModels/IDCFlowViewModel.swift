import SwiftUI
import UIKit

@MainActor
public final class IDCFlowViewModel: ObservableObject {

    enum PieceStatus: Equatable {
        case pending
        case captured
        case verifying
        case verified
        case rejected(reason: String)
        case transportFailed(message: String)
    }

    enum Phase: Equatable {
        case capturing(IDCPiece)
        case detecting(IDCPiece)
        case flipping(IDCPiece)
        // The captured photo is on screen awaiting the user's confirmation before it is uploaded.
        case confirming(IDCPiece)
        case verifying(IDCPiece)
        case review
        case done
    }

    struct FailureSheetInfo: Equatable, Identifiable {
        let piece: IDCPiece
        let failure: IDCCaptureFailure
        let image: UIImage?
        var id: String { piece.rawValue }
    }

    @Published private(set) var phase: Phase
    @Published private(set) var statuses: [IDCPiece: PieceStatus]
    @Published private(set) var showsVerifiedBeat = false
    @Published var failureSheetInfo: FailureSheetInfo?
    @Published var autoPresentPicker = false
    @Published private(set) var showsSkip = false

    @Published private(set) var configuration: IDCConfiguration

    private let verifier: IDCVerifier
    let analyzers: IDCAnalyzerProvider
    private let callbacks: IDCCallbacks

    private var results: [IDCPiece: IDCCaptureResult] = [:]
    private var payloads: [IDCPiece: Any] = [:]
    private var rejectionCounts: [IDCPiece: Int] = [:]
    private var verifyTasks: [IDCPiece: Task<Void, Never>] = [:]
    private var verifyGenerations: [IDCPiece: UInt] = [:]
    private var verifiedBeatTask: Task<Void, Never>?
    private var selfieOverlayFinished = false
    private var completed = false
    private var skipRevealTask: Task<Void, Never>?
    private var hasReportedSubject = false

    private static let verifiedBeatNanoseconds = IDCTheme.Animation.verifiedBeatNanoseconds

    public convenience init(
        configuration: IDCConfiguration,
        verifier: IDCVerifier,
        callbacks: IDCCallbacks
    ) {
        self.init(
            configuration: configuration,
            verifier: verifier,
            analyzers: IDCModelAnalyzerProvider(configuration: configuration, runner: IDCInference.runner),
            callbacks: callbacks
        )
    }

    init(
        configuration: IDCConfiguration,
        verifier: IDCVerifier,
        analyzers: IDCAnalyzerProvider,
        callbacks: IDCCallbacks
    ) {
        precondition(!configuration.pieces.isEmpty, "IDCConfiguration.pieces must not be empty")
        self.configuration = configuration
        self.verifier = verifier
        self.analyzers = analyzers
        self.callbacks = callbacks

        var statuses: [IDCPiece: PieceStatus] = [:]
        for piece in configuration.pieces { statuses[piece] = .pending }
        self.statuses = statuses
        self.phase = .capturing(configuration.pieces[0])
    }

    func onAppear() {
        IDCAnalytics.flowStarted(context: configuration.analyticsContext, pieces: configuration.pieces)
    }

    public func updateProgress(_ progress: IDCProgressStyle) {
        configuration.progress = progress
    }

    public func updateFlowTitle(_ title: String?) {
        guard configuration.flowTitle != title else { return }
        configuration.flowTitle = title
    }

    func subjectDetected() {
        if !hasReportedSubject, let piece = activePiece {
            hasReportedSubject = true
            callbacks.onSubjectDetected?(piece)
        }
        startSkipRevealIfNeeded()
    }

    private var activePiece: IDCPiece? {
        switch phase {
        case .capturing(let piece), .detecting(let piece), .verifying(let piece),
             .flipping(let piece), .confirming(let piece):
            return piece
        case .review, .done:
            return nil
        }
    }

    private func resetSubjectArming() {
        skipRevealTask?.cancel()
        skipRevealTask = nil
        hasReportedSubject = false
        showsSkip = false
        revealSkipIfRejectedEnough()
    }

    private func revealSkipIfRejectedEnough() {
        guard let skip = configuration.skip, callbacks.onSkip != nil, skip.appearsAfterRejections > 0 else { return }
        guard rejectionCounts.values.contains(where: { $0 >= skip.appearsAfterRejections }) else { return }
        skipRevealTask?.cancel()
        showsSkip = true
    }

    private func startSkipRevealIfNeeded() {
        guard let skip = configuration.skip, callbacks.onSkip != nil, skipRevealTask == nil else { return }
        skipRevealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(skip.appearsAfter, 0) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.showsSkip = true
        }
    }

    func skip() {
        guard callbacks.onSkip != nil else { return }
        skipRevealTask?.cancel()
        verifyTasks.values.forEach { $0.cancel() }
        verifiedBeatTask?.cancel()
        IDCAnalytics.flowExited(context: configuration.analyticsContext, at: phase.analyticsName)
        callbacks.onSkip?()
    }

    func captured(_ piece: IDCPiece, image: UIImage, fieldDetections: IDCFieldDetections?, source: IDCCaptureSource) {
        let result = IDCCaptureResult(piece: piece, image: image, source: source, fieldDetections: fieldDetections)
        if piece == .selfie { selfieOverlayFinished = false }
        results[piece] = result
        statuses[piece] = .captured
        skipRevealTask?.cancel()
        showsSkip = false
        callbacks.onPieceCaptured?(result)
        IDCAnalytics.pieceCaptured(context: configuration.analyticsContext, piece: piece, source: source)

        if source == .liveScan && piece.isPassport {
            phase = .detecting(piece)
        } else if source == .gallery {
            phase = .confirming(piece)
        } else {
            beginVerify(piece)
        }
    }

    func captureFailed(_ piece: IDCPiece, failure: IDCCaptureFailure, image: UIImage? = nil) {
        statuses[piece] = .pending
        IDCHaptics.error()
        failureSheetInfo = FailureSheetInfo(piece: piece, failure: failure, image: image)
    }

    func dismissFailureSheet() {
        failureSheetInfo = nil
    }

    func detectionFinished(_ piece: IDCPiece) {
        guard results[piece] != nil else { return }
        beginVerify(piece)
    }

    func flipFinished(_ piece: IDCPiece) {
        guard case .flipping(let current) = phase, current == piece else { return }
        phase = .capturing(piece)
    }

    /// The photo on the review step is accepted → upload it.
    func confirmCapture() {
        guard case .confirming(let piece) = phase else { return }
        beginVerify(piece)
    }

    /// The review step was dismissed without accepting → discard the photo and scan again.
    func cancelCapture() {
        guard case .confirming(let piece) = phase else { return }
        resetPiece(piece)
        phase = .capturing(piece)
    }

    /// The result currently awaiting confirmation, if the flow is on its review step.
    var confirmingResult: IDCCaptureResult? {
        guard case .confirming(let piece) = phase else { return nil }
        return results[piece]
    }

    private func beginVerify(_ piece: IDCPiece) {
        guard let result = results[piece] else { return }
        verifyGenerations[piece, default: 0] += 1
        let generation = verifyGenerations[piece] ?? 0
        statuses[piece] = .verifying
        phase = .verifying(piece)

        verifyTasks[piece]?.cancel()
        verifyTasks[piece] = Task { [weak self] in
            guard let self else { return }
            let outcome = await self.verifier.verify(result)
            guard !Task.isCancelled else { return }
            guard self.verifyGenerations[piece] == generation else { return }
            self.apply(outcome, for: piece, verifiedResult: result)
        }
    }

    private func apply(_ outcome: IDCVerificationOutcome, for piece: IDCPiece, verifiedResult: IDCCaptureResult) {
        guard results[piece]?.captureToken == verifiedResult.captureToken else { return }
        switch outcome {
        case .verified(let payload):
            statuses[piece] = .verified
            if let payload { payloads[piece] = payload }
            callbacks.onPieceVerified?(piece, payload)
            IDCAnalytics.pieceVerified(context: configuration.analyticsContext, piece: piece)
            if piece == .selfie {
                advanceVerifiedSelfieIfSettled()
            } else if isActivePiece(piece) {
                playVerifiedBeatThenAdvance()
            } else {
                advance()
            }

        case .rejected(let reason):
            rejectionCounts[piece, default: 0] += 1
            revealSkipIfRejectedEnough()
            statuses[piece] = .rejected(reason: reason)
            IDCHaptics.error()
            IDCAnalytics.pieceRejected(context: configuration.analyticsContext, piece: piece, reason: reason)
            let rejectedImage = verifiedResult.image
            resetPiece(piece)
            phase = .capturing(piece)
            failureSheetInfo = FailureSheetInfo(
                piece: piece,
                failure: .rejection(for: piece, reason: reason),
                image: rejectedImage
            )

        case .failed(let message):
            statuses[piece] = .transportFailed(message: message)
            phase = .verifying(piece)
        }
    }

    private func playVerifiedBeatThenAdvance() {
        IDCHaptics.success()
        showsVerifiedBeat = true
        verifiedBeatTask?.cancel()
        verifiedBeatTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.verifiedBeatNanoseconds)
            guard !Task.isCancelled, let self else { return }
            self.showsVerifiedBeat = false
            self.advance()
        }
    }

    func retryTransport(_ piece: IDCPiece) {
        beginVerify(piece)
    }

    func selfieCompletionFinished() {
        selfieOverlayFinished = true
        advanceVerifiedSelfieIfSettled()
    }

    private func advanceVerifiedSelfieIfSettled() {
        guard statuses[.selfie] == .verified, selfieOverlayFinished else { return }
        if isActivePiece(.selfie) {
            playVerifiedBeatThenAdvance()
        } else {
            advance()
        }
    }

    private func nextPendingPiece() -> IDCPiece? {
        configuration.pieces.first { statuses[$0] == .pending }
    }

    private func advance() {
        if let next = nextPendingPiece() {
            resetSubjectArming()
            if shouldTransitionToBackFlip() {
                phase = .flipping(.passportBack)
            } else {
                phase = .capturing(next)
            }
        } else {
            finishOrReview()
        }
    }

    private func finishOrReview() {
        guard allPiecesVerified else {
            phase = .review
            return
        }
        complete()
    }

    private func complete() {
        guard !completed else { return }
        completed = true
        phase = .done
        IDCAnalytics.flowCompleted(context: configuration.analyticsContext)
        callbacks.onComplete(results, payloads)
    }

    func rescanLive(_ piece: IDCPiece) {
        resetPiece(piece)
        autoPresentPicker = false
        failureSheetInfo = nil
        phase = .capturing(piece)
    }

    func reuploadFromDevice(_ piece: IDCPiece) {
        resetPiece(piece)
        failureSheetInfo = nil
        phase = .capturing(piece)
        autoPresentPicker = true
    }

    func rescan(_ piece: IDCPiece) {
        resetPiece(piece)
        phase = .capturing(piece)
    }

    private func resetPiece(_ piece: IDCPiece) {
        verifyTasks[piece]?.cancel()
        verifyTasks[piece] = nil
        verifyGenerations[piece, default: 0] += 1
        results[piece] = nil
        payloads[piece] = nil
        statuses[piece] = .pending
        if piece == .selfie { selfieOverlayFinished = false }
    }

    func exit() {
        skipRevealTask?.cancel()
        verifyTasks.values.forEach { $0.cancel() }
        verifiedBeatTask?.cancel()
        IDCAnalytics.flowExited(context: configuration.analyticsContext, at: phase.analyticsName)
        callbacks.onExit()
    }

    func status(for piece: IDCPiece) -> PieceStatus { statuses[piece] ?? .pending }
    func result(for piece: IDCPiece) -> IDCCaptureResult? { results[piece] }
    func rejectionCount(for piece: IDCPiece) -> Int { rejectionCounts[piece] ?? 0 }

    var orderedPieces: [IDCPiece] { configuration.pieces }

    var displayProgress: IDCProgressStyle {
        guard case .segments(let count, _) = configuration.progress else {
            return configuration.progress
        }
        return .segments(count: count, filled: progressFilledSegments)
    }

    var allPiecesVerified: Bool {
        configuration.pieces.allSatisfy { statuses[$0] == .verified }
    }

    private var progressFilledSegments: Int {
        guard case .segments(let count, let staticFilled) = configuration.progress else { return 0 }
        switch phase {
        case .review, .done:
            return count
        case .capturing(let piece), .detecting(let piece), .flipping(let piece),
             .confirming(let piece), .verifying(let piece):
            guard let index = configuration.pieces.firstIndex(of: piece) else { return staticFilled }
            let span = max(count, 1)
            return min(span, max(1, index + 1))
        }
    }

    private func shouldTransitionToBackFlip() -> Bool {
        guard let front = results[.passportFront], front.source == .liveScan else { return false }
        return nextPendingPiece() == .passportBack
    }

    private func isActivePiece(_ piece: IDCPiece) -> Bool {
        switch phase {
        case .capturing(let current), .detecting(let current), .verifying(let current),
             .confirming(let current):
            return current == piece
        case .flipping:
            return false
        case .review, .done:
            return false
        }
    }

    func reviewContinue() {
        if allPiecesVerified { finishOrReview() }
    }
}

private extension IDCFlowViewModel.Phase {
    var analyticsName: String {
        switch self {
        case .capturing: return "capturing"
        case .detecting: return "detecting"
        case .flipping: return "flipping"
        case .confirming: return "confirming"
        case .verifying: return "verifying"
        case .review: return "review"
        case .done: return "done"
        }
    }
}

#if DEBUG
extension IDCFlowViewModel {
    func seedForPreview(
        phase: Phase,
        results: [IDCPiece: IDCCaptureResult] = [:],
        statuses: [IDCPiece: PieceStatus] = [:],
        showsVerifiedBeat: Bool = false
    ) {
        self.results = results
        for (piece, status) in statuses { self.statuses[piece] = status }
        self.showsVerifiedBeat = showsVerifiedBeat
        self.phase = phase
    }
}
#endif
