#if DEBUG
import SwiftUI
import UIKit

enum IDCPreviewSupport {

    static func sampleImage(label: String, size: CGSize = CGSize(width: 660, height: 460), tint: UIColor = .systemIndigo) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            tint.withAlphaComponent(0.25).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            UIColor.white.withAlphaComponent(0.6).setFill()
            let inset = CGRect(origin: .zero, size: size).insetBy(dx: 24, dy: 24)
            UIBezierPath(roundedRect: inset, cornerRadius: 16).fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
                .foregroundColor: UIColor.darkGray,
            ]
            let text = label as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }

    static func passportResult(_ piece: IDCPiece, source: IDCCaptureSource = .liveScan) -> IDCCaptureResult {
        IDCCaptureResult(
            piece: piece,
            image: sampleImage(label: piece.displayName),
            source: source,
            fieldDetections: nil
        )
    }

    static func selfieResult(source: IDCCaptureSource = .liveScan) -> IDCCaptureResult {
        IDCCaptureResult(
            piece: .selfie,
            image: sampleImage(label: "Selfie", size: CGSize(width: 500, height: 500), tint: .systemTeal),
            source: source,
            fieldDetections: nil
        )
    }

    @MainActor
    static func viewModel(
        pieces: [IDCPiece] = [.passportFront, .passportBack, .selfie],
        configure: ((inout IDCConfiguration) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        seed: ((IDCFlowViewModel) -> Void)? = nil
    ) -> IDCFlowViewModel {
        var configuration = IDCConfiguration(pieces: pieces, flowTitle: "Identity check", analyticsContext: "preview")
        configure?(&configuration)
        let dismiss = onDismiss ?? {}
        let viewModel = IDCFlowViewModel(
            configuration: configuration,
            verifier: IDCMockVerifier(mode: .alwaysVerify),
            scanEngines: IDCNoopScanEngineProvider(),
            callbacks: IDCCallbacks(onComplete: { _, _ in dismiss() }, onExit: dismiss)
        )
        seed?(viewModel)
        return viewModel
    }

    @MainActor
    static func capturingPassport(
        piece: IDCPiece,
        priorVerified: [IDCPiece] = [],
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            let statuses = passportStatuses(priorVerified: priorVerified, active: piece, activeStatus: .pending)
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            vm.seedForPreview(phase: .capturing(piece), results: results, statuses: statuses)
        }
    }

    @MainActor
    static func detectingPassport(
        piece: IDCPiece,
        priorVerified: [IDCPiece] = [],
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            results[piece] = passportResult(piece, source: .liveScan)
            let statuses = passportStatuses(priorVerified: priorVerified, active: piece, activeStatus: .captured)
            vm.seedForPreview(phase: .detecting(piece), results: results, statuses: statuses)
        }
    }

    @MainActor
    static func passportFlipTransition(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            let front = passportResult(.passportFront, source: .liveScan)
            vm.seedForPreview(
                phase: .flipping(.passportBack),
                results: [.passportFront: front],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .pending,
                    .selfie: .pending,
                ]
            )
        }
    }

    @MainActor
    static func verifyingPassport(
        piece: IDCPiece = .passportFront,
        source: IDCCaptureSource = .gallery,
        priorVerified: [IDCPiece] = [],
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            results[piece] = passportResult(piece, source: source)
            let statuses = passportStatuses(priorVerified: priorVerified, active: piece, activeStatus: .verifying)
            vm.seedForPreview(phase: .verifying(piece), results: results, statuses: statuses)
        }
    }

    @MainActor
    static func verifiedPassportBeat(
        piece: IDCPiece = .passportFront,
        priorVerified: [IDCPiece] = [],
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            results[piece] = passportResult(piece, source: .gallery)
            let statuses = passportStatuses(priorVerified: priorVerified, active: piece, activeStatus: .verified)
            vm.seedForPreview(
                phase: .verifying(piece),
                results: results,
                statuses: statuses,
                showsVerifiedBeat: true
            )
        }
    }

    @MainActor
    static func passportInlineFailure(
        piece: IDCPiece = .passportFront,
        priorVerified: [IDCPiece] = [],
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            let statuses = passportStatuses(
                priorVerified: priorVerified,
                active: piece,
                activeStatus: .pending
            )
            vm.seedForPreview(phase: .capturing(piece), results: results, statuses: statuses)
            vm.failureSheetInfo = IDCFlowViewModel.FailureSheetInfo(
                piece: piece,
                failure: .rejection(for: piece, reason: IDCStrings.Failure.submitClearPassport),
                image: passportResult(piece).image
            )
        }
    }

    @MainActor
    static func passportTransportFailed(
        piece: IDCPiece = .passportFront,
        priorVerified: [IDCPiece] = [],
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            results[piece] = passportResult(piece)
            let statuses = passportStatuses(
                priorVerified: priorVerified,
                active: piece,
                activeStatus: .transportFailed(message: "Network error. Please try again.")
            )
            vm.seedForPreview(phase: .verifying(piece), results: results, statuses: statuses)
        }
    }

    @MainActor
    static func passportCameraDenied(
        piece: IDCPiece = .passportFront,
        priorVerified: [IDCPiece] = [],
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(
            configure: { $0.debugSimulateCameraDenied = true },
            onDismiss: onDismiss
        ) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            let statuses = passportStatuses(priorVerified: priorVerified, active: piece, activeStatus: .pending)
            vm.seedForPreview(phase: .capturing(piece), results: results, statuses: statuses)
        }
    }

    @MainActor
    static func passportCameraPrimer(
        piece: IDCPiece = .passportFront,
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(
            configure: { $0.debugSimulateCameraPrimer = true },
            onDismiss: onDismiss
        ) { vm in
            vm.seedForPreview(
                phase: .capturing(piece),
                results: [:],
                statuses: passportStatuses(priorVerified: [], active: piece, activeStatus: .pending)
            )
        }
    }

    @MainActor
    static func passportReminderLink(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(
            configure: { $0.debugRevealsReminderLinkImmediately = true },
            onDismiss: onDismiss
        ) { vm in
            vm.seedForPreview(
                phase: .capturing(.passportFront),
                results: [:],
                statuses: passportStatuses(priorVerified: [], active: .passportFront, activeStatus: .pending)
            )
        }
    }

    @MainActor
    static func selfieCoTravellerChooser(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(
            configure: { $0.selfieSubjectName = "Siddhi Bhansali" },
            onDismiss: onDismiss
        ) { vm in
            vm.seedForPreview(
                phase: .capturing(.selfie),
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                ],
                statuses: passportStatuses(
                    priorVerified: [.passportFront, .passportBack],
                    active: .selfie,
                    activeStatus: .pending
                )
            )
        }
    }

    @MainActor
    static func galleryConfirmSheet(
        piece: IDCPiece,
        priorVerified: [IDCPiece] = [],
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            let result = piece == .selfie
                ? selfieResult(source: .gallery)
                : passportResult(piece, source: .gallery)
            results[piece] = result
            var statuses: [IDCPiece: IDCFlowViewModel.PieceStatus] = [:]
            if piece.isPassport {
                statuses = passportStatuses(priorVerified: priorVerified, active: piece, activeStatus: .captured)
            } else {
                statuses = passportStatuses(
                    priorVerified: [.passportFront, .passportBack],
                    active: .selfie,
                    activeStatus: .captured
                )
            }
            vm.seedForPreview(phase: .confirming(piece), results: results, statuses: statuses)
        }
    }

    @MainActor
    static func failureSheet(
        piece: IDCPiece,
        priorVerified: [IDCPiece] = [],
        failure: IDCCaptureFailure? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> IDCFlowViewModel {
        let resolvedFailure = failure ?? (piece.isPassport ? .invalidPassport : .selfieIssue(nil))
        return viewModel(onDismiss: onDismiss) { vm in
            var results: [IDCPiece: IDCCaptureResult] = [:]
            for verified in priorVerified {
                results[verified] = passportResult(verified)
            }
            var statuses: [IDCPiece: IDCFlowViewModel.PieceStatus] = [:]
            if piece.isPassport {
                statuses = passportStatuses(priorVerified: priorVerified, active: piece, activeStatus: .pending)
            } else {
                statuses = passportStatuses(priorVerified: [.passportFront, .passportBack], active: .selfie, activeStatus: .pending)
            }
            vm.seedForPreview(phase: .capturing(piece), results: results, statuses: statuses)
            vm.failureSheetInfo = IDCFlowViewModel.FailureSheetInfo(
                piece: piece,
                failure: resolvedFailure,
                image: sampleImage(label: piece.isPassport ? "Upload" : "Selfie")
            )
        }
    }

    @MainActor
    static func selfieVerifying(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(pieces: [.passportFront, .passportBack, .selfie], onDismiss: onDismiss) { vm in
            let result = selfieResult()
            vm.seedForPreview(
                phase: .verifying(.selfie),
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                    .selfie: result,
                ],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .verified,
                    .selfie: .verifying,
                ]
            )
        }
    }

    @MainActor
    static func selfieVerifiedBeat(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(pieces: [.passportFront, .passportBack, .selfie], onDismiss: onDismiss) { vm in
            let result = selfieResult()
            vm.seedForPreview(
                phase: .verifying(.selfie),
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                    .selfie: result,
                ],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .verified,
                    .selfie: .verified,
                ],
                showsVerifiedBeat: true
            )
        }
    }

    @MainActor
    static func selfieInlineFailure(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(pieces: [.passportFront, .passportBack, .selfie], onDismiss: onDismiss) { vm in
            vm.seedForPreview(
                phase: .capturing(.selfie),
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                ],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .verified,
                    .selfie: .pending,
                ]
            )
            vm.failureSheetInfo = IDCFlowViewModel.FailureSheetInfo(
                piece: .selfie,
                failure: .rejection(for: .selfie, reason: IDCStrings.Failure.submitClearSelfie),
                image: selfieResult().image
            )
        }
    }

    @MainActor
    static func selfieCompletionOverlay(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(pieces: [.passportFront, .passportBack, .selfie], onDismiss: onDismiss) { vm in
            let result = selfieResult(source: .liveScan)
            vm.seedForPreview(
                phase: .capturing(.selfie),
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                    .selfie: result,
                ],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .verified,
                    .selfie: .captured,
                ]
            )
        }
    }

    @MainActor
    static func selfieCameraDenied(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(
            pieces: [.passportFront, .passportBack, .selfie],
            configure: { $0.debugSimulateCameraDenied = true },
            onDismiss: onDismiss
        ) { vm in
            vm.seedForPreview(
                phase: .capturing(.selfie),
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                ],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .verified,
                    .selfie: .pending,
                ]
            )
        }
    }

    @MainActor
    static func reviewMixed(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(pieces: [.passportFront, .passportBack], onDismiss: onDismiss) { vm in
            vm.seedForPreview(
                phase: .review,
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                ],
                statuses: [
                    .passportFront: .rejected(reason: "Unable to capture your details"),
                    .passportBack: .verified,
                ]
            )
        }
    }

    @MainActor
    static func reviewMixedFull(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            vm.seedForPreview(
                phase: .review,
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                    .selfie: selfieResult(),
                ],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .rejected(reason: "Unable to capture your details"),
                    .selfie: .verified,
                ]
            )
        }
    }

    @MainActor
    static func reviewAllVerified(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(pieces: [.passportFront, .passportBack], onDismiss: onDismiss) { vm in
            vm.seedForPreview(
                phase: .review,
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                ],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .verified,
                ]
            )
        }
    }

    @MainActor
    static func reviewAllVerifiedFull(onDismiss: (() -> Void)? = nil) -> IDCFlowViewModel {
        viewModel(onDismiss: onDismiss) { vm in
            vm.seedForPreview(
                phase: .review,
                results: [
                    .passportFront: passportResult(.passportFront),
                    .passportBack: passportResult(.passportBack),
                    .selfie: selfieResult(),
                ],
                statuses: [
                    .passportFront: .verified,
                    .passportBack: .verified,
                    .selfie: .verified,
                ]
            )
        }
    }

    private static func passportStatuses(
        priorVerified: [IDCPiece],
        active: IDCPiece,
        activeStatus: IDCFlowViewModel.PieceStatus
    ) -> [IDCPiece: IDCFlowViewModel.PieceStatus] {
        var statuses: [IDCPiece: IDCFlowViewModel.PieceStatus] = [
            .passportFront: .pending,
            .passportBack: .pending,
            .selfie: .pending,
        ]
        for piece in priorVerified {
            statuses[piece] = .verified
        }
        statuses[active] = activeStatus
        return statuses
    }
}
#endif
