import ATUIKit
import AVFoundation
import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct IDCPassportScanScreen: View {

    @ObservedObject var viewModel: IDCFlowViewModel
    let piece: IDCPiece

    @State private var activePicker: IDCPhotoPickerSource?
    @State private var pendingUpload: UIImage?
    @State private var showFileImporter = false
    @State private var checkingUpload: UIImage?
    @StateObject private var cameraGate = IDCCameraPermissionGate()
    @State private var reminderLinkRevealed = false
    @State private var liveGuidance: IDCPassportGuidance = .searching
    @StateObject private var analyzerHolder: IDCAnalyzerHolder<IDCPassportAnalyzer>
    @StateObject private var cameraService = IDCCameraService()

    init(viewModel: IDCFlowViewModel, piece: IDCPiece) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.piece = piece
        let analyzers = viewModel.analyzers
        _analyzerHolder = StateObject(wrappedValue: IDCAnalyzerHolder(analyzers.makePassportAnalyzer()))
    }

    private var isBackPage: Bool { piece == .passportBack }
    private var copy: IDCCaptureCopy { viewModel.configuration.copy(for: piece) }

    private var title: String {
        copy.title ?? (isBackPage ? IDCStrings.Capture.flipToBackPage : IDCStrings.Capture.scanPassport)
    }

    private var subtitle: String {
        copy.subtitle ?? IDCStrings.Capture.captureWhenInFocus
    }

    private let headerIcon: IDCCaptureHeader.Icon = .asset(IDCTheme.Assets.passportDoc)

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.configuration.showsScanTopBar {
                IDCScanTopBar(
                    title: viewModel.configuration.resolvedFlowTitle,
                    progress: viewModel.displayProgress,
                    showsBack: viewModel.configuration.showsBack,
                    onBack: { viewModel.exit() },
                    trailingSystemImage: viewModel.configuration.scanTopBarTrailingSystemImage,
                    onTrailingTap: viewModel.configuration.onScanTopBarTrailingTap
                )
                .idcScanTopBarTopSpacing(
                    basePadding: viewModel.configuration.scanTopBarBaseTopPadding,
                    includesSafeAreaTop: viewModel.configuration.scanTopBarIncludesSafeAreaTop
                )
                .padding(.horizontal, IDCTheme.Layout.screenHorizontalPadding)
            }

            IDCCaptureHeader(
                icon: headerIcon,
                title: title,
                subtitle: subtitle,
                highlightFrom: IDCStrings.Capture.captureWhenInFocusHighlight
            )
            .padding(.top, viewModel.configuration.showsScanTopBar ? viewModel.configuration.headerTopPadding : IDCTheme.Layout.topBarTopPadding)

            if let accessory = viewModel.configuration.headerAccessory {
                accessory
                    .padding(.top, IDCTheme.Layout.headerAccessoryTopPadding)
            }

            IDCScanViewfinder(caption: copy.eyebrow ?? piece.defaultEyebrow) {
                viewportContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, viewModel.configuration.viewfinderTopPadding)
            .padding(.horizontal, IDCTheme.Layout.screenHorizontalPadding)

            bottomArea
                .padding(.top, IDCTheme.Layout.bottomAreaTopPadding)
                .padding(.horizontal, IDCTheme.Layout.screenHorizontalPadding)
                .padding(.bottom, IDCTheme.Layout.bottomAreaBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IDCTheme.Colors.screenBackground.ignoresSafeArea())
        .overlay {
            if cameraGate.awaitingSystemPrompt {
                IDCPermissionPromptSpotlight()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: cameraGate.awaitingSystemPrompt)
        .sheet(item: $activePicker, onDismiss: consumePendingUpload) { picker in
            IDCImagePicker(sourceType: picker.type) { image in pendingUpload = image }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image, .pdf]) { result in
            handleImportedFile(result)
        }
        .onAppear {
            analyzerHolder.analyzer.prepare()
            consumeAutoPresentPickerIfNeeded()
        }
        .onChange(of: viewModel.autoPresentPicker) { consumeAutoPresentPickerIfNeeded() }
        .fullScreenCover(isPresented: $cameraGate.showsPrimer) {
            IDCCameraPrimerScreen {
                Task { await cameraGate.requestAccess() }
            }
        }
        .task { cameraGate.resolve(configuration: viewModel.configuration) }
        .task {
            #if DEBUG
            if viewModel.configuration.debugRevealsReminderLinkImmediately {
                reminderLinkRevealed = true
                return
            }
            #endif
            try? await Task.sleep(nanoseconds: viewModel.configuration.reminderLinkRevealNanoseconds)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { reminderLinkRevealed = true }
        }
    }

    private func consumeAutoPresentPickerIfNeeded() {
        guard viewModel.autoPresentPicker, case .capturing(let current) = viewModel.phase, current == piece else { return }
        viewModel.autoPresentPicker = false
        activePicker = IDCPhotoPickerSource(type: .photoLibrary)
    }

    @ViewBuilder
    private var viewportContent: some View {
        switch viewModel.phase {
        case .detecting(let current) where current == piece:
            if let result = viewModel.result(for: piece) {
                IDCPassportDetectionOverlay(
                    image: result.image,
                    detections: result.fieldDetections,
                    page: isBackPage ? .back : .front
                ) {
                    viewModel.detectionFinished(piece)
                }
                .idcViewfinderSurface()
            }

        case .flipping(let current) where current == piece:
            if let front = viewModel.result(for: .passportFront) {
                IDCPassportFlipView(
                    image: front.image,
                    detections: front.fieldDetections,
                    onFinished: { viewModel.flipFinished(piece) }
                )
            }

        case .verifying(let current) where current == piece:
            if let result = viewModel.result(for: piece) {
                if case .transportFailed = viewModel.status(for: piece) {
                    IDCConnectionErrorOverlay(image: result.image)
                        .idcViewfinderSurface()
                } else if result.source == .liveScan {
                    let page: IDCPassportDetectionVisual.Page = isBackPage ? .back : .front
                    IDCPassportDetectionVisual(
                        image: result.image,
                        visibleCount: IDCPassportDetectionVisual.sections(for: page).count,
                        page: page,
                        detections: result.fieldDetections
                    )
                    .idcViewfinderSurface()
                } else {
                    IDCProcessingStill(image: result.image)
                        .idcViewfinderSurface()
                }
            }

        default:
            if let checkingUpload {
                IDCProcessingStill(image: checkingUpload)
                    .idcViewfinderSurface()
            } else if let result = viewModel.result(for: piece), case .confirming = viewModel.phase {
                IDCProcessingStill(image: result.image)
                    .idcViewfinderSurface()
            } else if cameraGate.cameraRestricted {
                IDCCameraDeniedPanel(
                    title: IDCStrings.Camera.restrictedTitle,
                    message: IDCStrings.Camera.passportRestrictedMessage,
                    showsSettingsButton: false
                )
                .idcViewfinderSurface()
            } else if cameraGate.cameraDenied {
                IDCCameraDeniedPanel()
                    .idcViewfinderSurface()
            } else if cameraGate.cameraReady {
                IDCPassportCameraView(
                    cameraService: cameraService,
                    isForBackPage: isBackPage,
                    analyzer: analyzerHolder.analyzer,
                    guidance: $liveGuidance,
                    onCaptured: { image, detections in
                        viewModel.captured(piece, image: image, fieldDetections: detections, source: .liveScan)
                    },
                    onPassportSeen: { viewModel.subjectDetected() }
                )
                .id(piece)
            } else {
                Color.clear
                    .idcViewfinderSurface()
            }
        }
    }

    private var bottomArea: some View {
        VStack(spacing: 8) {
            subStatusLine
                .frame(minHeight: footerState == .idle ? IDCTheme.Layout.scanSubStatusHeight : 0)
            IDCCaptureFooter(
                state: footerState,
                showsUpload: viewModel.configuration.allowUploadFromDevice,
                showsReminderLink: viewModel.configuration.showsReminderLink && !isBackPage && reminderLinkRevealed,
                skipTitle: viewModel.showsSkip ? viewModel.configuration.skip?.title : nil,
                onUpload: { presentUploadSourceSheet() },
                onRetry: { viewModel.retryTransport(piece) },
                onReminderTap: { presentReminderSheet() },
                onSkip: { viewModel.skip() },
                minHeight: viewModel.configuration.footerMinHeight
            )
        }
    }

    private func presentReminderSheet() {
        IDCHaptics.sheet()
        ATBottomSheetWindowPresenter.present(
            cornerRadius: IDCTheme.Sheet.cornerRadius,
            dimmedBackdropOpacity: IDCTheme.Sheet.darkBackdropOpacity
        ) {
            IDCReminderSheet(onScheduled: viewModel.configuration.onReminderSet)
        }
    }

    @ViewBuilder
    private var subStatusLine: some View {
        if let subStatus = liveSubStatus {
            Text(subStatus.text)
                .typoGraphy(.B1InterMedium14)
                .foregroundStyle(subStatus.color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        } else {
            Color.clear.frame(height: 0)
        }
    }

    private var liveSubStatus: (text: String, color: Color)? {
        guard footerState == .idle, cameraGate.cameraReady else { return nil }
        guard let copy = liveGuidance.copy(isForBackPage: isBackPage) else {
            return (IDCStrings.PassportGuidance.positionInGuides, Color.neutralGrey500)
        }
        guard let tip = copy.tip else { return nil }
        return (tip, copy.isError ? IDCTheme.Colors.statusAlertBackground : Color.neutralGrey500)
    }

    private var footerState: IDCCaptureFooter.State {
        switch viewModel.phase {
        case .verifying(let current) where current == piece:
            if case .transportFailed(let message) = viewModel.status(for: piece) {
                return .retry(message: message)
            }
            return viewModel.showsVerifiedBeat
                ? .verified(caption: IDCStrings.Footer.verified)
                : .verifying(caption: IDCStrings.Footer.verifyingPassport)
        case .detecting(let current) where current == piece:
            return .disabled
        case .flipping(let current) where current == piece:
            return .disabled
        default:
            if checkingUpload != nil || viewModel.result(for: piece) != nil {
                return .disabled
            }
            return .idle
        }
    }

    private func presentUploadSourceSheet() {
        IDCUploadSourceSheet.presentForCapture(
            onImportFile: viewModel.configuration.onScanTopBarTrailingTap ?? { showFileImporter = true },
            onPick: { source in activePicker = IDCPhotoPickerSource(type: source) }
        )
    }

    private func consumePendingUpload() {
        guard let image = pendingUpload else { return }
        pendingUpload = nil
        handleUpload(image)
    }

    private func handleImportedFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let image = (try? Data(contentsOf: url)).flatMap(IDCImportedFile.image(from:))

            DispatchQueue.main.async {
                guard let image else {
                    viewModel.captureFailed(piece, failure: .unreadablePhoto)
                    return
                }
                handleUpload(image)
            }
        }
    }

    private func handleUpload(_ image: UIImage) {
        viewModel.subjectDetected()
        checkingUpload = image
        let analyzer = analyzerHolder.analyzer
        let isBackPage = isBackPage
        Task {
            let analysis = await analyzer.analyzePhoto(image, isForBackPage: isBackPage)
            checkingUpload = nil
            switch IDCUploadCheck.passport(analysis, image: image, isForBackPage: isBackPage) {
            case .accepted(let cropped, let detections):
                viewModel.captured(piece, image: cropped, fieldDetections: detections, source: .gallery)
            case .rejected(let failure):
                viewModel.captureFailed(piece, failure: failure, image: image)
            }
        }
    }
}

private struct IDCPassportCameraView: View {
    @ObservedObject var cameraService: IDCCameraService
    let isForBackPage: Bool
    @Binding var guidance: IDCPassportGuidance
    let onCaptured: (UIImage, IDCFieldDetections?) -> Void
    let onPassportSeen: () -> Void

    @StateObject private var liveScan: IDCPassportLiveScan

    init(
        cameraService: IDCCameraService,
        isForBackPage: Bool,
        analyzer: IDCPassportAnalyzer,
        guidance: Binding<IDCPassportGuidance>,
        onCaptured: @escaping (UIImage, IDCFieldDetections?) -> Void,
        onPassportSeen: @escaping () -> Void = {}
    ) {
        _cameraService = ObservedObject(wrappedValue: cameraService)
        self.isForBackPage = isForBackPage
        _guidance = guidance
        self.onCaptured = onCaptured
        self.onPassportSeen = onPassportSeen
        _liveScan = StateObject(wrappedValue: IDCPassportLiveScan(analyzer: analyzer))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                IDCCameraPreview(session: cameraService.session)

                if liveScan.guidance == .holdStill {
                    IDCHoldStillPreviewTint()
                        .transition(.opacity)
                }

                IDCCornerBracketsShape(
                    cornerRadius: IDCTheme.Layout.passportBracketCornerRadius,
                    armLength: IDCTheme.Layout.passportBracketArmLength
                )
                    .stroke(
                        bracketColor,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                    .aspectRatio(1.586, contentMode: .fit)
                    .padding(.horizontal, IDCTheme.Layout.passportBracketHorizontalPadding)

                if liveScan.isProcessing {
                    Color.black.opacity(0.25)
                    ProgressView().tint(.white).scaleEffect(1.3)
                }
            }
            .idcViewfinderSurface()

            if let pill {
                IDCStatusPill(text: pill.text, tone: pill.tone, systemIcon: pill.systemIcon)
                    .offset(y: IDCTheme.Layout.statusPillEdgeOverlap)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: liveScan.guidance)
        .onAppear(perform: startCamera)
        .onDisappear {
            cameraService.stopSession()
            liveScan.stop()
        }
        .onReceive(liveScan.$guidance) { guidance = $0 }
        .onReceive(liveScan.$hasSeenPassport.filter { $0 }) { _ in onPassportSeen() }
        .onReceive(liveScan.$capturedImage.compactMap { $0 }) { image in
            cameraService.stopSession()
            onCaptured(image, liveScan.capturedFieldDetections)
        }
    }

    private func startCamera() {
        liveScan.start(isForBackPage: isForBackPage)
        weak let scan = liveScan
        cameraService.configureForVideo(position: .back) { sampleBuffer in
            scan?.process(sampleBuffer)
        } onConfigured: {
            cameraService.startSession()
        }
    }

    private var pill: (text: String, tone: IDCStatusPill.Tone, systemIcon: String?)? {
        guard let copy = liveScan.guidance.copy(isForBackPage: isForBackPage) else { return nil }
        return (copy.pill, copy.tone, copy.isError ? "exclamationmark.circle.fill" : nil)
    }

    private var bracketColor: Color {
        if liveScan.guidance.copy(isForBackPage: isForBackPage)?.isError == true {
            return IDCTheme.Colors.statusAlertBackground.opacity(0.55)
        }
        switch liveScan.guidance {
        case .holdStill: return .green
        default: return liveScan.isGoodFrame ? .green : .white
        }
    }
}

private struct IDCPassportGuidanceCopy {
    let pill: String
    let tip: String?
    let tone: IDCStatusPill.Tone
    let isError: Bool

    static func error(_ pill: String, _ tip: String) -> Self {
        .init(pill: pill, tip: tip, tone: .alert, isError: true)
    }

    static func coaching(_ pill: String, _ tip: String) -> Self {
        .init(pill: pill, tip: tip, tone: .coaching, isError: false)
    }

    static func capturing(_ pill: String) -> Self {
        .init(pill: pill, tip: nil, tone: .capturing, isError: false)
    }
}

private extension IDCPassportGuidance {
    func copy(isForBackPage: Bool = false) -> IDCPassportGuidanceCopy? {
        typealias Copy = IDCStrings.PassportGuidance
        switch self {
        case .wrongPage:
            return .error(
                isForBackPage ? Copy.frontPageShown : Copy.backPageShown,
                isForBackPage ? Copy.frontPageShownTip : Copy.backPageShownTip
            )
        case .glare:
            return .error(Copy.glareDetected, Copy.glareDetectedTip)
        case .lightReflection:
            return .error(Copy.lightReflection, Copy.lightReflectionTip)
        case .fingers:
            return .error(Copy.fingersDetected, Copy.fingersDetectedTip)
        case .travelDoc:
            return .error(Copy.notAPassport, Copy.notAPassportTip)
        case .moveCloser:
            return .coaching(Copy.moveCloser, Copy.moveCloserTip)
        case .tooClose:
            return .coaching(Copy.tooClose, Copy.tooCloseTip)
        case .outOfBox:
            return .coaching(Copy.outOfGuides, Copy.outOfGuidesTip)
        case .holdStill:
            return .capturing(Copy.capturing)
        case .searching:
            return nil
        }
    }
}

struct IDCCameraDeniedPanel: View {
    var title: String = IDCStrings.Camera.permissionRequired
    var message: String = IDCStrings.Camera.passportPermissionMessage
    var showsSettingsButton: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            badge

            Text(title)
                .typoGraphy(.H7InterMedium16)
                .tracking(-0.4)
                .foregroundStyle(.white)
                .padding(.top, 22)

            Text(message)
                .typoGraphy(.B2InterMedium12)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 10)
                .padding(.horizontal, 32)

            if showsSettingsButton {
                ATButton(
                    IDCStrings.CTA.giveAccess,
                    size: .medium,
                    variant: .primary,
                    colorStyle: .white
                ) {
                    IDCHaptics.tap()
                    IDCCameraPermission.openSettings()
                }
                .frame(width: 180)
                .padding(.top, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var badge: some View {
        IDCScallopBadgeShape()
            .fill(Color.white.opacity(0.14))
            .frame(width: 60, height: 60)
            .overlay {
                IDCIcon(ATIcon.SwiftUIImage.cameraAlt, size: 24)
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.30))
                    .offset(x: 12, y: -8)
            }
    }
}

struct IDCScallopBadgeShape: Shape {
    var lobes: Int = 10
    var depth: CGFloat = 0.045

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2
        let steps = 240
        var path = Path()
        for step in 0...steps {
            let theta = CGFloat(step) / CGFloat(steps) * 2 * .pi
            let radius = base * (1 - depth + depth * cos(CGFloat(lobes) * theta))
            let point = CGPoint(x: center.x + radius * cos(theta), y: center.y + radius * sin(theta))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Front → back flip") {
    IDCPassportScanScreen(viewModel: IDCPreviewSupport.passportFlipTransition(), piece: .passportBack)
}

#Preview("Verifying (gallery still)") {
    IDCPassportScanScreen(viewModel: IDCPreviewSupport.verifyingPassport(), piece: .passportFront)
}

#Preview("Verified beat") {
    IDCPassportScanScreen(viewModel: IDCPreviewSupport.verifiedPassportBeat(), piece: .passportFront)
}

#Preview("Rejection → failure sheet") {
    IDCFlowView(viewModel: IDCPreviewSupport.passportInlineFailure())
}

#Preview("Guidance states") {
    let states: [IDCPassportGuidance] = [
        .searching, .moveCloser, .tooClose, .outOfBox, .fingers,
        .glare, .lightReflection, .wrongPage, .travelDoc, .holdStill
    ]
    return ScrollView {
        VStack(spacing: 20) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                VStack(spacing: 6) {
                    if let copy = state.copy(isForBackPage: true) {
                        IDCStatusPill(
                            text: copy.pill,
                            tone: copy.tone,
                            systemIcon: copy.isError ? "exclamationmark.circle.fill" : nil
                        )
                        if let tip = copy.tip {
                            Text(tip)
                                .typoGraphy(.B1InterMedium14)
                                .foregroundStyle(copy.isError ? IDCTheme.Colors.statusAlertBackground : Color.neutralGrey500)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 200)
                        }
                    } else {
                        Text(IDCStrings.PassportGuidance.positionInGuides)
                            .typoGraphy(.B1InterMedium14)
                            .foregroundStyle(Color.neutralGrey500)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 200)
                    }
                    Text(String(describing: state))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    .background(IDCTheme.Colors.screenBackground)
}

#Preview("Camera denied panel") {
    IDCCameraDeniedPanel()
        .frame(height: 420)
        .background(Color.pureBlack)
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .padding(20)
}
#endif
