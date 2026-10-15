import UIKit

enum ApplicationCaptureLauncher {

    typealias StorePassportHandler = (_ passport: PassportData, _ isForBackPage: Bool) -> Bool
    typealias SelfieStoredHandler = (_ capturedLive: Bool?) -> Void
    typealias CapturedImageHandler = (_ piece: IDCPiece, _ image: UIImage) -> Void

    // MARK: - Passport

    @MainActor
    static func presentPassport(
        from presenter: UIViewController,
        context: ApplicationCaptureContext,
        pieces: [IDCPiece],
        copy: [IDCPiece: IDCCaptureCopy] = [:],
        onCapturedImage: CapturedImageHandler? = nil,
        storePassport: @escaping StorePassportHandler,
        onComplete: @escaping () -> Void,
        onExit: @escaping () -> Void = {}
    ) {
        presentPassport(
            presentation: .push(on: presenter),
            context: context,
            pieces: pieces,
            copy: copy,
            onCapturedImage: onCapturedImage,
            storePassport: storePassport,
            onComplete: onComplete,
            onExit: onExit
        )
    }

    @MainActor
    static func embedPassport(
        in host: ApplicationCaptureEmbedding,
        context: ApplicationCaptureContext,
        pieces: [IDCPiece],
        copy: [IDCPiece: IDCCaptureCopy] = [:],
        onCapturedImage: CapturedImageHandler? = nil,
        storePassport: @escaping StorePassportHandler,
        onComplete: @escaping () -> Void,
        onExit: @escaping () -> Void = {}
    ) {
        presentPassport(
            presentation: .embedded(host: host),
            context: context,
            pieces: pieces,
            copy: copy,
            onCapturedImage: onCapturedImage,
            storePassport: storePassport,
            onComplete: onComplete,
            onExit: onExit
        )
    }

    @MainActor
    static func presentPassportModally(
        from host: UIViewController,
        context: ApplicationCaptureContext,
        pieces: [IDCPiece],
        copy: [IDCPiece: IDCCaptureCopy] = [:],
        onCapturedImage: CapturedImageHandler? = nil,
        storePassport: @escaping StorePassportHandler,
        onComplete: @escaping () -> Void,
        onExit: @escaping () -> Void = {}
    ) {
        presentPassport(
            presentation: .modal(host: host),
            context: context,
            pieces: pieces,
            copy: copy,
            onCapturedImage: onCapturedImage,
            storePassport: storePassport,
            onComplete: onComplete,
            onExit: onExit
        )
    }

    @MainActor
    private static func presentPassport(
        presentation: ApplicationCapturePresentation,
        context: ApplicationCaptureContext,
        pieces: [IDCPiece],
        copy: [IDCPiece: IDCCaptureCopy],
        onCapturedImage: CapturedImageHandler?,
        storePassport: @escaping StorePassportHandler,
        onComplete: @escaping () -> Void,
        onExit: @escaping () -> Void
    ) {
        guard !pieces.isEmpty else {
            onComplete()
            return
        }

        var configuration = IDCConfiguration(
            pieces: pieces,
            flowTitle: nil,
            analyticsContext: "visa_\(context.scanLocation.rawValue)"
        )
        configuration.copy = copy
        configuration.ocrSettings = context.passportOcrSettings
        configuration.progress = .segments(count: max(pieces.count, 1), filled: 1)
        configuration.allowUploadFromDevice = true
        applyFunnelChrome(to: &configuration, context: context, presentation: presentation)
        configuration.onReminderSet = { date in
            AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                applicationId: context.applicationId,
                withName: "PassportUploadReminderSet",
                parameters: ["scheduledAt": date.timeIntervalSince1970]
            )
        }

        logPassportCaptureInitiated(context: context, pieces: pieces)

        let verifier = IDCVisaPassportVerifier(context: context)

        pushFlow(
            presentation: presentation,
            configuration: configuration,
            context: context,
            verifier: verifier,
            callbacks: IDCCallbacks(
                onPieceVerified: { piece, _ in
                    if piece == .passportFront, pieces.contains(.passportBack) {
                        logPassportScreenView(context: context, piece: .passportBack)
                    }
                },
                onComplete: { results, payloads in
                    handlePassportComplete(
                        context: context,
                        results: results,
                        payloads: payloads,
                        onCapturedImage: onCapturedImage,
                        storePassport: storePassport,
                        onComplete: onComplete
                    )
                },
                onExit: onExit
            )
        )
    }

    @MainActor
    private static func handlePassportComplete(
        context: ApplicationCaptureContext,
        results: [IDCPiece: IDCCaptureResult],
        payloads: [IDCPiece: Any],
        onCapturedImage: CapturedImageHandler?,
        storePassport: StorePassportHandler,
        onComplete: @escaping () -> Void
    ) {
        let applicationId = context.applicationId
        let orderedPieces: [IDCPiece] = [.passportFront, .passportBack].filter { results[$0] != nil }

        for piece in orderedPieces {
            if let capture = results[piece] {
                onCapturedImage?(piece, capture.image)
            }

            guard let passport = payloads[piece] as? PassportData,
                  let capture = results[piece] else { continue }

            let isForBackPage = piece == .passportBack
            let eventName: String
            if let coTravelerId = context.coTravelerId {
                eventName = isForBackPage ? "b2c_co_traveler_passport_back_uploaded" : "b2c_co_traveler_passport_front_uploaded"
                AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                    applicationId: applicationId,
                    withName: eventName,
                    parameters: [
                        "liveOrCamera": capture.source == .liveScan ? "live" : "camera",
                        "coTravelerId": coTravelerId,
                        "isCoTraveler": true,
                        "uploaded_by": "co_traveler",
                        "upload_doc_type": isForBackPage ? "passport_back" : "passport_front"
                    ]
                )
            } else {
                eventName = isForBackPage ? "b2c_passport_back_uploaded" : "b2c_passport_front_uploaded"
                AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                    applicationId: applicationId,
                    withName: eventName,
                    parameters: [
                        "liveOrCamera": capture.source == .liveScan ? "live" : "camera",
                        "isCoTraveler": false,
                        "uploaded_by": "self",
                        "upload_doc_type": isForBackPage ? "passport_back" : "passport_front"
                    ]
                )
            }

            if storePassport(passport, isForBackPage) {
                return
            }
        }

        onComplete()
    }

    private static func logPassportCaptureInitiated(context: ApplicationCaptureContext, pieces: [IDCPiece]) {
        var params: [String: Any] = ["ScanMode": "LiveScanning", "captureModule": "IDC"]
        if let coTravelerId = context.coTravelerId {
            params["firebase_co_traveler_id"] = coTravelerId
        }
        for piece in pieces where piece.isPassport {
            AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                applicationId: context.applicationId,
                withName: piece == .passportBack
                    ? "PassportBackPageCaptureInitiated"
                    : "PassportFrontPageCaptureInitiated",
                parameters: params
            )
        }
        if let firstPiece = pieces.first {
            logPassportScreenView(context: context, piece: firstPiece)
        }
    }

    private static func logPassportScreenView(context: ApplicationCaptureContext, piece: IDCPiece) {
        guard context.scanLocation == .funnel, piece.isPassport else { return }
        if let coTravelerId = context.coTravelerId {
            let eventName = piece == .passportBack ? "CoTravellerPassportBack" : "CoTravellerPassport"
            AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                applicationId: context.applicationId,
                withName: eventName,
                asScreenView: true,
                parameters: ["coTravelerId": coTravelerId]
            )
        } else {
            AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                applicationId: context.applicationId,
                withName: piece == .passportBack ? "PassportBack" : "PassportFront",
                asScreenView: true
            )
        }
    }

    // MARK: - Selfie

    @MainActor
    static func presentSelfie(
        from presenter: UIViewController,
        context: ApplicationCaptureContext,
        onCapturedImage: CapturedImageHandler? = nil,
        onStored: @escaping SelfieStoredHandler,
        onExit: @escaping () -> Void = {}
    ) {
        presentSelfie(
            presentation: .push(on: presenter),
            context: context,
            onCapturedImage: onCapturedImage,
            onStored: onStored,
            onExit: onExit
        )
    }

    @MainActor
    static func embedSelfie(
        in host: ApplicationCaptureEmbedding,
        context: ApplicationCaptureContext,
        onCapturedImage: CapturedImageHandler? = nil,
        onStored: @escaping SelfieStoredHandler,
        onExit: @escaping () -> Void = {}
    ) {
        presentSelfie(
            presentation: .embedded(host: host),
            context: context,
            onCapturedImage: onCapturedImage,
            onStored: onStored,
            onExit: onExit
        )
    }

    @MainActor
    static func presentSelfieModally(
        from host: UIViewController,
        context: ApplicationCaptureContext,
        onCapturedImage: CapturedImageHandler? = nil,
        onStored: @escaping SelfieStoredHandler,
        onExit: @escaping () -> Void = {}
    ) {
        presentSelfie(
            presentation: .modal(host: host),
            context: context,
            onCapturedImage: onCapturedImage,
            onStored: onStored,
            onExit: onExit
        )
    }

    @MainActor
    private static func presentSelfie(
        presentation: ApplicationCapturePresentation,
        context: ApplicationCaptureContext,
        onCapturedImage: CapturedImageHandler?,
        onStored: @escaping SelfieStoredHandler,
        onExit: @escaping () -> Void
    ) {
        var configuration = IDCConfiguration(
            pieces: [.selfie],
            flowTitle: nil,
            analyticsContext: "visa_\(context.scanLocation.rawValue)_selfie"
        )
        configuration.progress = .hidden
        configuration.allowUploadFromDevice = true
        configuration.selfieLiveCaptureSettings = context.selfieLiveCaptureSettings
        configuration.selfieUploadCaptureSettings = context.selfieUploadCaptureSettings
        applyFunnelChrome(to: &configuration, context: context, presentation: presentation)

        AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
            applicationId: context.applicationId,
            withName: "SelfieCaptureInitiated",
            parameters: ["captureModule": "IDC"]
        )

        if context.coTravelerId == nil {
            AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                applicationId: context.applicationId,
                withName: "Selfie",
                asScreenView: true
            )
        } else if context.scanLocation == .funnel, let coTravelerId = context.coTravelerId {
            AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                applicationId: context.applicationId,
                withName: "CoTravellerSelfie",
                asScreenView: true,
                parameters: ["coTravelerId": coTravelerId]
            )
        }

        pushFlow(
            presentation: presentation,
            configuration: configuration,
            context: context,
            verifier: IDCSelfieApplicationVerifier(context: context),
            callbacks: IDCCallbacks(
                onComplete: { results, _ in
                    guard let result = results[.selfie] else {
                        onStored(nil)
                        return
                    }
                    onCapturedImage?(.selfie, result.image)
                    let capturedLive = result.source == .liveScan
                    AnalyticsEventManager.sharedInstance.logPostHogApplicationEvent(
                        applicationId: context.applicationId,
                        withName: context.coTravelerId == nil ? "b2c_selfie_uploaded" : "b2c_co_traveler_photo_scanned",
                        parameters: [
                            "liveOrCamera": capturedLive ? "live" : "camera",
                            "captureLocation": context.scanLocation.rawValue,
                            "isPassportScanned": UserData.currentUser?.passport?.documentNumber != nil
                        ]
                    )
                    onStored(capturedLive)
                },
                onExit: onExit
            )
        )
    }

    @MainActor
    private static func pushFlow(
        presentation: ApplicationCapturePresentation,
        configuration: IDCConfiguration,
        context captureContext: ApplicationCaptureContext,
        verifier: IDCVerifier,
        callbacks: IDCCallbacks
    ) {
        let pushContext = ApplicationCapturePushContext()

        let flowViewController = IDCFactory.makeViewController(
            configuration: configuration,
            verifier: verifier,
            callbacks: wiredIDCCallbacks(
                from: callbacks,
                presentation: presentation,
                pushContext: pushContext
            )
        )
        pushContext.viewController = flowViewController

        switch presentation {
        case .push(let presenter):
            IDCNavigator.push(
                flowViewController,
                from: presenter,
                navBarBehavior: funnelNavBarBehavior(for: captureContext.scanLocation)
            )
        case .modal(let host):
            let navigationController = UINavigationController(rootViewController: flowViewController)
            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.modalPresentationStyle = .overFullScreen
            navigationController.modalTransitionStyle = .crossDissolve
            pushContext.presentedNavigationController = navigationController
            host.present(navigationController, animated: true)
        case .embedded(let host):
            host.embedCaptureFlow(flowViewController)
        }
    }

    @MainActor
    private static func wiredIDCCallbacks(
        from callbacks: IDCCallbacks,
        presentation: ApplicationCapturePresentation,
        pushContext: ApplicationCapturePushContext
    ) -> IDCCallbacks {
        IDCCallbacks(
            onPieceCaptured: callbacks.onPieceCaptured,
            onPieceVerified: callbacks.onPieceVerified,
            onComplete: { results, payloads in
                finishFlow(presentation: presentation, pushContext: pushContext) {
                    callbacks.onComplete(results, payloads)
                }
            },
            onExit: {
                finishFlow(presentation: presentation, pushContext: pushContext, then: callbacks.onExit)
            }
        )
    }

    @MainActor
    private static func finishFlow(
        presentation: ApplicationCapturePresentation,
        pushContext: ApplicationCapturePushContext,
        then completion: @escaping () -> Void
    ) {
        switch presentation {
        case .push:
            IDCNavigator.dismiss(pushContext.viewController, then: completion)
        case .modal(let host):
            if let navigationController = pushContext.presentedNavigationController {
                navigationController.dismiss(animated: true, completion: completion)
            } else {
                host.dismiss(animated: true, completion: completion)
            }
        case .embedded:
            completion()
        }
    }

    private static func applyFunnelChrome(
        to configuration: inout IDCConfiguration,
        context: ApplicationCaptureContext,
        presentation: ApplicationCapturePresentation
    ) {
        guard context.scanLocation == .funnel else { return }
        switch presentation {
        case .push, .embedded:
            configuration.showsScanTopBar = false
            configuration.showsBack = false
        case .modal:
            configuration.showsBack = true
        }
    }

    private static func funnelNavBarBehavior(for location: ApplicationCaptureLocation) -> AVNavBarBehavior? {
        guard location == .funnel else { return nil }
        return AVNavBarBehavior(displayETALabel: true)
    }

    // MARK: - Image only (no visa OCR / persistence)

    @MainActor
    private static func presentImageOnly(
        from presenter: UIViewController,
        piece: IDCPiece,
        context: ApplicationCaptureContext,
        analyticsContext: String,
        scanTopBarPlacement: IDCScanTopBarPlacement,
        presentation: ApplicationCapturePresentation? = nil,
        selfieLiveCaptureSettings: SelfieCaptureSettings? = nil,
        selfieUploadCaptureSettings: SelfieCaptureSettings? = nil,
        onImportFile: (() -> Void)?,
        onFinished: @escaping (UIImage?) -> Void
    ) {
        var configuration = IDCConfiguration(
            pieces: [piece],
            flowTitle: nil,
            analyticsContext: analyticsContext
        )
        configuration.allowUploadFromDevice = true
        configuration.progress = .hidden
        configuration.scanTopBarPlacement = scanTopBarPlacement
        if let onImportFile {
            configuration.scanTopBarTrailingSystemImage = "folder"
            configuration.onScanTopBarTrailingTap = onImportFile
        }

        configuration.selfieLiveCaptureSettings = selfieLiveCaptureSettings
        configuration.selfieUploadCaptureSettings = selfieUploadCaptureSettings

        pushFlow(
            presentation: presentation ?? .push(on: presenter),
            configuration: configuration,
            context: context,
            verifier: IDCPassThroughVerifier(),
            callbacks: IDCCallbacks(
                onComplete: { results, _ in
                    onFinished(results[piece]?.image)
                },
                onExit: { onFinished(nil) }
            )
        )
    }

    // MARK: - DS-160 / US post-checkout

    /// The DS-160 package asks the host for a selfie and keeps the image itself, so this stores
    /// nothing. Presented modally to match the handler it replaces — the package owns its own
    /// navigation stack and pushing into it would fight that.
    @MainActor
    static func presentDS160Selfie(
        from presenter: UIViewController,
        applicationId: String,
        coTravelerId: String?,
        onFinished: @escaping (UIImage?) -> Void
    ) {
        let bouncer = UserData.currentUser?.applications[applicationId]?.bouncerRequirement
        presentImageOnly(
            from: presenter,
            piece: .selfie,
            context: ApplicationCaptureContext(
                applicationId: applicationId,
                scanLocation: .usPostCheckout,
                coTravelerId: coTravelerId
            ),
            analyticsContext: "us_post_checkout_selfie",
            scanTopBarPlacement: .standard,
            presentation: .modal(host: presenter),
            selfieLiveCaptureSettings: bouncer?.getLiveCaptureSettings() ?? .allFalse(),
            selfieUploadCaptureSettings: bouncer?.getUploadCaptureSettings() ?? .allFalse(),
            onImportFile: nil,
            onFinished: onFinished
        )
    }

    @MainActor
    static func presentDS160Passport(
        from presenter: UIViewController,
        applicationId: String,
        isBackPageRequired: Bool,
        onFinished: @escaping (UIImage?, UIImage?) -> Void
    ) {
        let pieces: [IDCPiece] = isBackPageRequired ? [.passportFront, .passportBack] : [.passportFront]

        var configuration = IDCConfiguration(
            pieces: pieces,
            flowTitle: nil,
            analyticsContext: "ds160_passport"
        )
        configuration.allowUploadFromDevice = true
        configuration.progress = .segments(count: pieces.count, filled: 1)

        pushFlow(
            presentation: .modal(host: presenter),
            configuration: configuration,
            context: ApplicationCaptureContext(
                applicationId: applicationId,
                scanLocation: .usPostCheckout
            ),
            verifier: IDCPassThroughVerifier(),
            callbacks: IDCCallbacks(
                onComplete: { results, _ in
                    onFinished(results[.passportFront]?.image, results[.passportBack]?.image)
                },
                onExit: { onFinished(nil, nil) }
            )
        )
    }

    // MARK: - DocVault

    @MainActor
    static func presentDocVaultPassport(
        from presenter: UIViewController,
        isForBackPage: Bool,
        onImportFile: (() -> Void)? = nil,
        onFinished: @escaping (UIImage?) -> Void
    ) {
        presentImageOnly(
            from: presenter,
            piece: isForBackPage ? .passportBack : .passportFront,
            context: ApplicationCaptureContext(
                applicationId: UserData.currentUser?.currentApplicationId ?? "doc_vault",
                scanLocation: .docVault
            ),
            analyticsContext: "doc_vault_passport",
            scanTopBarPlacement: .embeddedSheet,
            onImportFile: onImportFile,
            onFinished: onFinished
        )
    }

    @MainActor
    static func presentDocVaultSelfie(
        from presenter: UIViewController,
        onFinished: @escaping (UIImage?) -> Void
    ) {
        presentImageOnly(
            from: presenter,
            piece: .selfie,
            context: ApplicationCaptureContext(
                applicationId: UserData.currentUser?.currentApplicationId ?? "doc_vault",
                scanLocation: .docVault,
                selfieLiveCaptureSettings: SelfieCaptureSettings.allFalse(),
                selfieUploadCaptureSettings: SelfieCaptureSettings.allFalse()
            ),
            analyticsContext: "doc_vault_selfie",
            scanTopBarPlacement: .embeddedSheet,
            onImportFile: nil,
            onFinished: onFinished
        )
    }

    // MARK: - Post-checkout re-upload

    @MainActor
    static func presentPostCheckoutDocument(
        from presenter: UIViewController,
        piece: IDCPiece,
        applicationId: String,
        coTravelerId: String?,
        onImportFile: (() -> Void)? = nil,
        onFinished: @escaping (UIImage?) -> Void
    ) {
        presentImageOnly(
            from: presenter,
            piece: piece,
            context: ApplicationCaptureContext(
                applicationId: applicationId,
                scanLocation: .other,
                coTravelerId: coTravelerId,
                selfieLiveCaptureSettings: SelfieCaptureSettings.allFalse(),
                selfieUploadCaptureSettings: SelfieCaptureSettings.allFalse()
            ),
            analyticsContext: "post_checkout_\(piece.rawValue)",
            scanTopBarPlacement: .standard,
            onImportFile: onImportFile,
            onFinished: onFinished
        )
    }
}

@MainActor
protocol ApplicationCaptureEmbedding: AnyObject {
    func embedCaptureFlow(_ viewController: UIViewController)
}

enum ApplicationCapturePresentation {
    case push(on: UIViewController)
    case modal(host: UIViewController)
    case embedded(host: ApplicationCaptureEmbedding)
}

@MainActor
private final class ApplicationCapturePushContext {
    weak var viewController: UIViewController?
    weak var presentedNavigationController: UINavigationController?
}
