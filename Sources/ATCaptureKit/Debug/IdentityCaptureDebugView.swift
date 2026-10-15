#if DEBUG
import ATUIKit
import SwiftUI
import UIKit

// MARK: - Cases

enum IdentityCaptureDebugCase: Identifiable {
    case live(Live)
    case seeded(Seeded)

    var id: String {
        switch self {
        case .live(let live): return "live.\(live.id)"
        case .seeded(let seeded): return "seeded.\(seeded.id)"
        }
    }

    var title: String {
        switch self {
        case .live(let live): return live.title
        case .seeded(let seeded): return seeded.title
        }
    }

    var subtitle: String? {
        switch self {
        case .live(let live): return live.subtitle
        case .seeded(let seeded): return seeded.subtitle
        }
    }

    enum Live: String, CaseIterable, Identifiable {
        case fullHappyPath
        case fullRejectFirst
        case fullAlwaysReject
        case fullTransportFail
        case passportOnly
        case selfieOnly
        case usPostCheckoutPassport
        case postCheckoutDocumentUpload

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fullHappyPath: return "Full flow · Happy path"
            case .fullRejectFirst: return "Full flow · Reject first attempt"
            case .fullAlwaysReject: return "Full flow · Always reject"
            case .fullTransportFail: return "Full flow · Transport fail"
            case .passportOnly: return "Passport front + back · Happy path"
            case .selfieOnly: return "Selfie only · Happy path"
            case .usPostCheckoutPassport: return "US post-checkout · Consular login gate"
            case .postCheckoutDocumentUpload: return "Post-checkout · Pending doc re-upload"
            }
        }

        var subtitle: String? {
            switch self {
            case .fullHappyPath: return "Mock verifier always succeeds"
            case .fullRejectFirst: return "First capture per piece is rejected"
            case .fullAlwaysReject: return "Every verification is rejected"
            case .fullTransportFail: return "Simulates a network / transport error"
            case .passportOnly, .selfieOnly: return "Subset of pieces, always succeeds"
            case .usPostCheckoutPassport: return "Front + back with the consular-login copy"
            case .postCheckoutDocumentUpload: return "Image only, no progress, file-import action"
            }
        }

        var pieces: [IDCPiece] {
            switch self {
            case .fullHappyPath, .fullRejectFirst, .fullAlwaysReject, .fullTransportFail:
                return [.passportFront, .passportBack, .selfie]
            case .passportOnly, .usPostCheckoutPassport:
                return [.passportFront, .passportBack]
            case .selfieOnly:
                return [.selfie]
            case .postCheckoutDocumentUpload:
                return [.passportFront]
            }
        }

        @MainActor
        func makeConfiguration() -> IDCConfiguration {
            var configuration = IDCConfiguration(
                pieces: pieces,
                flowTitle: "Identity check",
                analyticsContext: "debug"
            )
            switch self {
            case .usPostCheckoutPassport:
                configuration.copy = [
                    .passportFront: IDCCaptureCopy(
                        title: "Your Passport is required to verify your identity",
                        subtitle: "Upload the front page of your passport"
                    ),
                    .passportBack: IDCCaptureCopy(title: "Upload the back page of your passport")
                ]
            case .postCheckoutDocumentUpload:
                configuration.progress = .hidden
                configuration.scanTopBarTrailingSystemImage = "folder"
                configuration.onScanTopBarTrailingTap = {
                    print("[IdentityCaptureDebug] File import tapped")
                }
            default:
                break
            }
            return configuration
        }

        @MainActor
        var verifier: IDCMockVerifier {
            switch self {
            case .fullHappyPath, .passportOnly, .selfieOnly, .usPostCheckoutPassport, .postCheckoutDocumentUpload:
                return IDCMockVerifier(mode: .alwaysVerify)
            case .fullRejectFirst:
                return IDCMockVerifier(
                    mode: .rejectFirst(count: 1, reason: IDCStrings.Failure.submitClearPassport)
                )
            case .fullAlwaysReject:
                return IDCMockVerifier(mode: .alwaysReject(reason: IDCStrings.Failure.submitClearPassport))
            case .fullTransportFail:
                return IDCMockVerifier(mode: .transportFail(message: "Network error. Please try again."))
            }
        }
    }

    enum SeededGroup: String, CaseIterable, Identifiable {
        case passportFront = "Passport · Front"
        case passportBack = "Passport · Back"
        case selfie = "Selfie"
        case review = "Review"
        case sheets = "Sheets"

        var id: String { rawValue }

        var cases: [Seeded] {
            Seeded.allCases.filter { $0.group == self }
        }
    }

    enum Seeded: String, CaseIterable, Identifiable {
        case passportFrontDetecting
        case passportFrontVerifying
        case passportFrontVerifiedBeat
        case passportFrontFlipTransition
        case passportFrontInlineFailure
        case passportFrontTransportFailed
        case passportFrontCameraDenied
        case passportFrontCameraPrimer
        case passportFrontReminderLink
        case passportBackCapturing
        case passportBackDetecting
        case passportBackVerifying
        case passportBackVerifiedBeat
        case passportBackInlineFailure
        case selfieVerifying
        case selfieVerifiedBeat
        case selfieInlineFailure
        case selfieCompletionOverlay
        case selfieCameraDenied
        case selfieCoTravellerChooser
        case reviewMixed
        case reviewMixedFull
        case reviewAllVerified
        case reviewAllVerifiedFull
        case galleryConfirmFront
        case galleryConfirmBack
        case galleryConfirmSelfie
        case failureSheetFront
        case failureSheetBack
        case failureSheetSelfie

        var id: String { rawValue }

        var group: SeededGroup {
            switch self {
            case .passportFrontDetecting, .passportFrontVerifying, .passportFrontVerifiedBeat,
                 .passportFrontFlipTransition, .passportFrontInlineFailure, .passportFrontTransportFailed,
                 .passportFrontCameraDenied, .passportFrontCameraPrimer, .passportFrontReminderLink:
                return .passportFront
            case .passportBackCapturing, .passportBackDetecting, .passportBackVerifying,
                 .passportBackVerifiedBeat, .passportBackInlineFailure:
                return .passportBack
            case .selfieVerifying, .selfieVerifiedBeat, .selfieInlineFailure,
                 .selfieCompletionOverlay, .selfieCameraDenied, .selfieCoTravellerChooser:
                return .selfie
            case .reviewMixed, .reviewMixedFull, .reviewAllVerified, .reviewAllVerifiedFull:
                return .review
            case .galleryConfirmFront, .galleryConfirmBack, .galleryConfirmSelfie,
                 .failureSheetFront, .failureSheetBack, .failureSheetSelfie:
                return .sheets
            }
        }

        var title: String {
            switch self {
            case .passportFrontDetecting: return "Detecting (live scan)"
            case .passportFrontVerifying: return "Verifying"
            case .passportFrontVerifiedBeat: return "Verified beat"
            case .passportFrontFlipTransition: return "Front → back flip"
            case .passportFrontInlineFailure: return "Inline failure"
            case .passportFrontTransportFailed: return "Transport failed"
            case .passportFrontCameraDenied: return "Camera denied"
            case .passportFrontCameraPrimer: return "Camera primer"
            case .passportFrontReminderLink: return "Reminder flow"
            case .passportBackCapturing: return "Capturing (live camera)"
            case .passportBackDetecting: return "Detecting (live scan)"
            case .passportBackVerifying: return "Verifying"
            case .passportBackVerifiedBeat: return "Verified beat"
            case .passportBackInlineFailure: return "Inline failure"
            case .selfieVerifying: return "Verifying"
            case .selfieVerifiedBeat: return "Verified beat"
            case .selfieInlineFailure: return "Inline failure"
            case .selfieCompletionOverlay: return "Completion overlay"
            case .selfieCameraDenied: return "Camera denied"
            case .selfieCoTravellerChooser: return "Co-traveller photo chooser"
            case .reviewMixed: return "Mixed · Passport only"
            case .reviewMixedFull: return "Mixed · Full flow"
            case .reviewAllVerified: return "All verified · Passport only"
            case .reviewAllVerifiedFull: return "All verified · Full flow"
            case .galleryConfirmFront: return "Gallery confirm · Front"
            case .galleryConfirmBack: return "Gallery confirm · Back"
            case .galleryConfirmSelfie: return "Gallery confirm · Selfie"
            case .failureSheetFront: return "Failure sheet · Front"
            case .failureSheetBack: return "Failure sheet · Back"
            case .failureSheetSelfie: return "Failure sheet · Selfie"
            }
        }

        var subtitle: String? {
            switch self {
            case .passportFrontDetecting, .passportBackDetecting:
                return "Green detection overlay after live capture"
            case .passportFrontFlipTransition:
                return "3D flip from front scan to back-page prompt"
            case .passportFrontVerifying, .passportBackVerifying, .selfieVerifying:
                return "Frozen on the verifying overlay"
            case .passportFrontVerifiedBeat, .passportBackVerifiedBeat, .selfieVerifiedBeat:
                return "Success haptic / beat animation"
            case .passportFrontInlineFailure, .passportBackInlineFailure, .selfieInlineFailure:
                return "Inline rescan prompt with action buttons"
            case .passportFrontTransportFailed:
                return "Retry footer during verification"
            case .passportFrontCameraDenied, .selfieCameraDenied:
                return "Camera permission blocked panel"
            case .passportFrontCameraPrimer:
                return "Pre-permission explainer before the native prompt"
            case .passportFrontReminderLink:
                return "\u{201C}Don't have it handy?\u{201D} shown immediately (no 10s wait)"
            case .selfieCoTravellerChooser:
                return "Upload-or-capture sheet for someone else's photo"
            case .passportBackCapturing:
                return "Back-page scan UI with front already verified"
            case .selfieCompletionOverlay:
                return "PERFECT! ring fill before verify"
            case .reviewMixed, .reviewMixedFull:
                return "One piece rejected, others verified"
            case .reviewAllVerified, .reviewAllVerifiedFull:
                return "Ready to continue"
            case .galleryConfirmFront, .galleryConfirmBack, .galleryConfirmSelfie:
                return "Gallery upload confirmation sheet open"
            case .failureSheetFront, .failureSheetBack, .failureSheetSelfie:
                return "Full failure bottom sheet open"
            }
        }

        private var backPriorVerified: [IDCPiece] { [.passportFront] }

        @MainActor
        func makeViewModel(onDismiss: @escaping () -> Void) -> IDCFlowViewModel {
            switch self {
            case .passportFrontDetecting:
                return IDCPreviewSupport.detectingPassport(piece: .passportFront, onDismiss: onDismiss)
            case .passportFrontVerifying:
                return IDCPreviewSupport.verifyingPassport(onDismiss: onDismiss)
            case .passportFrontVerifiedBeat:
                return IDCPreviewSupport.verifiedPassportBeat(onDismiss: onDismiss)
            case .passportFrontFlipTransition:
                return IDCPreviewSupport.passportFlipTransition(onDismiss: onDismiss)
            case .passportFrontInlineFailure:
                return IDCPreviewSupport.passportInlineFailure(onDismiss: onDismiss)
            case .passportFrontTransportFailed:
                return IDCPreviewSupport.passportTransportFailed(onDismiss: onDismiss)
            case .passportFrontCameraDenied:
                return IDCPreviewSupport.passportCameraDenied(onDismiss: onDismiss)
            case .passportFrontCameraPrimer:
                return IDCPreviewSupport.passportCameraPrimer(onDismiss: onDismiss)
            case .passportFrontReminderLink:
                return IDCPreviewSupport.passportReminderLink(onDismiss: onDismiss)
            case .passportBackCapturing:
                return IDCPreviewSupport.capturingPassport(
                    piece: .passportBack,
                    priorVerified: backPriorVerified,
                    onDismiss: onDismiss
                )
            case .passportBackDetecting:
                return IDCPreviewSupport.detectingPassport(
                    piece: .passportBack,
                    priorVerified: backPriorVerified,
                    onDismiss: onDismiss
                )
            case .passportBackVerifying:
                return IDCPreviewSupport.verifyingPassport(
                    piece: .passportBack,
                    priorVerified: backPriorVerified,
                    onDismiss: onDismiss
                )
            case .passportBackVerifiedBeat:
                return IDCPreviewSupport.verifiedPassportBeat(
                    piece: .passportBack,
                    priorVerified: backPriorVerified,
                    onDismiss: onDismiss
                )
            case .passportBackInlineFailure:
                return IDCPreviewSupport.passportInlineFailure(
                    piece: .passportBack,
                    priorVerified: backPriorVerified,
                    onDismiss: onDismiss
                )
            case .selfieVerifying:
                return IDCPreviewSupport.selfieVerifying(onDismiss: onDismiss)
            case .selfieVerifiedBeat:
                return IDCPreviewSupport.selfieVerifiedBeat(onDismiss: onDismiss)
            case .selfieInlineFailure:
                return IDCPreviewSupport.selfieInlineFailure(onDismiss: onDismiss)
            case .selfieCompletionOverlay:
                return IDCPreviewSupport.selfieCompletionOverlay(onDismiss: onDismiss)
            case .selfieCameraDenied:
                return IDCPreviewSupport.selfieCameraDenied(onDismiss: onDismiss)
            case .selfieCoTravellerChooser:
                return IDCPreviewSupport.selfieCoTravellerChooser(onDismiss: onDismiss)
            case .reviewMixed:
                return IDCPreviewSupport.reviewMixed(onDismiss: onDismiss)
            case .reviewMixedFull:
                return IDCPreviewSupport.reviewMixedFull(onDismiss: onDismiss)
            case .reviewAllVerified:
                return IDCPreviewSupport.reviewAllVerified(onDismiss: onDismiss)
            case .reviewAllVerifiedFull:
                return IDCPreviewSupport.reviewAllVerifiedFull(onDismiss: onDismiss)
            case .galleryConfirmFront:
                return IDCPreviewSupport.galleryConfirmSheet(piece: .passportFront, onDismiss: onDismiss)
            case .galleryConfirmBack:
                return IDCPreviewSupport.galleryConfirmSheet(
                    piece: .passportBack,
                    priorVerified: backPriorVerified,
                    onDismiss: onDismiss
                )
            case .galleryConfirmSelfie:
                return IDCPreviewSupport.galleryConfirmSheet(piece: .selfie, onDismiss: onDismiss)
            case .failureSheetFront:
                return IDCPreviewSupport.failureSheet(piece: .passportFront, onDismiss: onDismiss)
            case .failureSheetBack:
                return IDCPreviewSupport.failureSheet(
                    piece: .passportBack,
                    priorVerified: backPriorVerified,
                    onDismiss: onDismiss
                )
            case .failureSheetSelfie:
                return IDCPreviewSupport.failureSheet(piece: .selfie, onDismiss: onDismiss)
            }
        }
    }

    static let liveCases: [IdentityCaptureDebugCase] = Live.allCases.map { .live($0) }
}

// MARK: - Launcher

enum IdentityCaptureDebugLauncher {

    @MainActor static var scanEngines: IDCScanEngineProvider = IDCNoopScanEngineProvider()

    @MainActor
    static func launch(_ item: IdentityCaptureDebugCase, from presenter: UIViewController) {
        switch item {
        case .live(let live):
            launchLiveFlow(configuration: live.makeConfiguration(), verifier: live.verifier, from: presenter)
        case .seeded(let seeded):
            presentModally(from: presenter) { dismiss in
                let viewModel = seeded.makeViewModel(onDismiss: dismiss)
                return IDCFlowViewController(viewModel: viewModel)
            }
        }
    }

    @MainActor
    private static func launchLiveFlow(
        configuration: IDCConfiguration,
        verifier: IDCMockVerifier,
        from presenter: UIViewController
    ) {
        presentModally(from: presenter) { dismiss in
            IDCFactory.makeViewController(
                configuration: configuration,
                verifier: verifier,
                scanEngines: scanEngines,
                callbacks: IDCCallbacks(
                    onComplete: { results, _ in
                        print("[IdentityCaptureDebug] Identity capture complete — \(results.count) piece(s)")
                        dismiss()
                    },
                    onExit: dismiss
                )
            )
        }
    }

    @MainActor
    private static func presentModally(
        from presenter: UIViewController,
        makeViewController: (_ dismiss: @escaping () -> Void) -> UIViewController
    ) {
        var flowNavigationController: UINavigationController?
        let dismiss: () -> Void = {
            flowNavigationController?.dismiss(animated: true)
        }

        let flowViewController = makeViewController(dismiss)
        let navigationController = UINavigationController(rootViewController: flowViewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.modalPresentationStyle = .overFullScreen
        navigationController.modalTransitionStyle = .crossDissolve
        flowNavigationController = navigationController
        presenter.present(navigationController, animated: true)
    }
}

// MARK: - View

@MainActor
final class IdentityCaptureDebugController: ObservableObject {
    weak var host: UIViewController?
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func launch(_ item: IdentityCaptureDebugCase) {
        guard let host else { return }
        IdentityCaptureDebugLauncher.launch(item, from: host)
    }
}

public struct IdentityCaptureDebugView: View {
    @ObservedObject var controller: IdentityCaptureDebugController

    public var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Launch interactive flows against a mock verifier, or jump straight into a seeded UI state. Pop back here after each run to try another case.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Live flows") {
                    ForEach(IdentityCaptureDebugCase.liveCases) { item in
                        caseRow(item)
                    }
                }

                ForEach(IdentityCaptureDebugCase.SeededGroup.allCases) { group in
                    Section(group.rawValue) {
                        ForEach(group.cases) { seeded in
                            caseRow(.seeded(seeded))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Identity Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { controller.onClose() }
                }
            }
        }
    }

    private func caseRow(_ item: IdentityCaptureDebugCase) -> some View {
        Button {
            controller.launch(item)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .foregroundStyle(Color(at: .pureBlack))
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color(at: .neutralGrey500))
                }
            }
        }
    }
}

// MARK: - Host

public final class IdentityCaptureDebugHostingController: UIHostingController<IdentityCaptureDebugView> {

    public init(scanEngines: IDCScanEngineProvider? = nil, onClose: @escaping () -> Void) {
        IdentityCaptureDebugLauncher.scanEngines = scanEngines ?? IDCNoopScanEngineProvider()
        let controller = IdentityCaptureDebugController(onClose: onClose)
        super.init(rootView: IdentityCaptureDebugView(controller: controller))
        controller.host = self
        view.backgroundColor = UIColor(Color(at: .pureWhite))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
