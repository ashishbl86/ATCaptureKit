import ATUIKit
import AVFoundation
import Combine
import CoreMotion
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct IDCSelfieScanScreen: View {

    @ObservedObject var viewModel: IDCFlowViewModel
    private let piece: IDCPiece = .selfie

    @State private var activePicker: IDCPhotoPickerSource?
    @State private var pendingUpload: UIImage?
    @State private var showFileImporter = false
    @State private var checkingUpload: UIImage?
    @StateObject private var cameraGate = IDCCameraPermissionGate()
    @State private var isGoodFrame = false
    @State private var captureProgress: Double = 0
    @State private var capturedMirrored = false
    @State private var cameraPosition: IDCCameraService.CameraPosition = .front
    @State private var selfieMessage = ""
    @State private var showCoTravellerChooser = false
    @State private var coTravellerChooserShown = false
    @State private var uploadAfterChooserDismiss = false
    @StateObject private var engineHolder: IDCScanEngineHolder<IDCSelfieScanEngine>
    @StateObject private var cameraService = IDCCameraService()

    init(viewModel: IDCFlowViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        let scanEngines = viewModel.scanEngines
        _engineHolder = StateObject(wrappedValue: IDCScanEngineHolder(scanEngines.makeSelfieEngine()))
    }

    private var copy: IDCCaptureCopy { viewModel.configuration.copy(for: piece) }
    private var title: String { copy.title ?? IDCStrings.Capture.takeSelfie }
    private var subtitle: String { copy.subtitle ?? IDCStrings.Capture.selfieRequired }

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

            IDCCaptureHeader(icon: .image(ATIcon.SwiftUIImage.filterCenterFocus), title: title, subtitle: subtitle)
                .padding(.top, viewModel.configuration.showsScanTopBar ? viewModel.configuration.headerTopPadding : IDCTheme.Layout.topBarTopPadding)

            scannerArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, viewModel.configuration.selfieScannerTopPadding)
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
        .sheet(isPresented: $showCoTravellerChooser, onDismiss: {
            if uploadAfterChooserDismiss {
                uploadAfterChooserDismiss = false
                activePicker = IDCPhotoPickerSource(type: .photoLibrary)
            }
        }) {
            IDCCoTravellerPhotoSheet(
                name: viewModel.configuration.selfieSubjectName ?? "",
                flowTitle: viewModel.configuration.flowTitle,
                progress: viewModel.displayProgress,
                onUpload: {
                    uploadAfterChooserDismiss = true
                    showCoTravellerChooser = false
                },
                onCaptureLive: { showCoTravellerChooser = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear { IDCHaptics.sheet() }
        }
        .onAppear {
            engineHolder.engine.prepare()
            consumeAutoPresentPickerIfNeeded()
            presentCoTravellerChooserIfNeeded()
        }
        .onChange(of: viewModel.autoPresentPicker) { consumeAutoPresentPickerIfNeeded() }
        .fullScreenCover(isPresented: $cameraGate.showsPrimer) {
            IDCCameraPrimerScreen(message: IDCStrings.Camera.selfiePermissionMessage) {
                Task { await cameraGate.requestAccess() }
            }
        }
        .task { cameraGate.resolve(configuration: viewModel.configuration) }
    }

    private func consumeAutoPresentPickerIfNeeded() {
        guard viewModel.autoPresentPicker, case .capturing(let current) = viewModel.phase, current == piece else { return }
        viewModel.autoPresentPicker = false
        activePicker = IDCPhotoPickerSource(type: .photoLibrary)
    }

    private func presentCoTravellerChooserIfNeeded() {
        guard viewModel.configuration.selfieSubjectName != nil,
              !coTravellerChooserShown,
              case .capturing(let current) = viewModel.phase, current == piece else { return }
        coTravellerChooserShown = true
        showCoTravellerChooser = true
    }

    private var scannerArea: some View {
        let frozen = frozenImage
        let ringVisible = frozen == nil && checkingUpload == nil && cameraGate.cameraReady && (isGoodFrame || captureProgress > 0)

        return VStack(spacing: IDCTheme.Layout.selfieCoachingPillBelowRingSpacing) {
            if cameraGate.cameraRestricted {
                IDCCameraDeniedPanel(
                    title: IDCStrings.Camera.restrictedTitle,
                    message: IDCStrings.Camera.selfieRestrictedMessage,
                    showsSettingsButton: false
                )
                .idcViewfinderSurface()
                .aspectRatio(1, contentMode: .fit)
            } else if cameraGate.cameraDenied {
                IDCCameraDeniedPanel(message: IDCStrings.Camera.selfiePermissionMessage)
                    .idcViewfinderSurface()
                    .aspectRatio(1, contentMode: .fit)
            } else {
                scannerCircle(frozen: frozen, ringVisible: ringVisible)
            }

            subStatusLine
                .frame(minHeight: IDCTheme.Layout.scanSubStatusHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .animation(.easeInOut(duration: 0.2), value: selfiePill?.text)
    }

    private func scannerCircle(frozen: UIImage?, ringVisible: Bool) -> some View {
            ZStack {
                Circle()
                    .trim(from: 0, to: captureProgress)
                    .stroke(
                        IDCTheme.Colors.statusCapturingBackground,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .opacity(ringVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: captureProgress)

                Group {
                    if let checkingUpload {
                        IDCProcessingStill(image: checkingUpload)
                    } else if let image = frozen {
                        if hasTransportFailure {
                            IDCConnectionErrorOverlay(image: image)
                        } else if isConfirming {
                            IDCProcessingStill(image: image, mirrored: capturedMirrored)
                        } else {
                            IDCSelfieCompletionOverlay(image: image, mirrored: capturedMirrored) {
                                viewModel.selfieCompletionFinished()
                            }
                        }
                    } else if !cameraGate.cameraReady {
                        Color.pureBlack
                    } else {
                        IDCSelfieCameraView(
                            cameraService: cameraService,
                            isGoodFrame: $isGoodFrame,
                            captureProgress: $captureProgress,
                            statusMessage: $selfieMessage,
                            engine: engineHolder.engine,
                            position: cameraPosition,
                            onCaptured: { image in
                                capturedMirrored = cameraPosition == .front
                                viewModel.captured(piece, image: image, fieldDetections: nil, source: .liveScan)
                            },
                            onFaceSeen: { viewModel.subjectDetected() }
                        )
                    }
                }
                .clipShape(Circle())
                .overlay(alignment: .bottom) {
                    if let pill = selfiePill {
                        IDCStatusPill(text: pill.text, tone: pill.tone, systemIcon: pill.systemIcon)
                            .offset(y: IDCTheme.Layout.statusPillEdgeOverlap)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if frozen == nil && checkingUpload == nil && cameraGate.cameraReady {
                        cameraFlipButton
                            .offset(x: 20, y: -10)
                    }
                }
                .padding(IDCTheme.Layout.selfieRingPadding)
            }
            .aspectRatio(1, contentMode: .fit)
    }

    private struct SelfiePill: Equatable {
        let text: String
        let tone: IDCStatusPill.Tone
        var systemIcon: String?
    }

    private var hasTransportFailure: Bool {
        if case .transportFailed = viewModel.status(for: piece) { return true }
        return false
    }

    private var isCompleting: Bool {
        frozenImage != nil && checkingUpload == nil && !isConfirming && !hasTransportFailure
    }

    private var isLiveCamera: Bool {
        frozenImage == nil && checkingUpload == nil && cameraGate.cameraReady && !cameraGate.cameraBlocked
    }

    fileprivate struct LiveGuidance {
        let pill: String
        let tip: String
    }

    private var liveGuidance: LiveGuidance? {
        guard let message = IDCSelfieGuidance(rawValue: selfieMessage) else { return nil }
        return Self.guidance(for: message)
    }

    fileprivate static func guidance(for message: IDCSelfieGuidance) -> LiveGuidance? {
        typealias Copy = IDCStrings.SelfieGuidance
        switch message {
        case .tooDark:
            return LiveGuidance(pill: Copy.lowLight, tip: Copy.lowLightTip)
        case .tooBright:
            return LiveGuidance(pill: Copy.tooBright, tip: Copy.tooBrightTip)
        case .multipleFaces:
            return LiveGuidance(pill: Copy.multipleFaces, tip: Copy.multipleFacesTip)
        case .notASelfie:
            return LiveGuidance(pill: Copy.notASelfie, tip: Copy.notASelfieTip)
        case .holdStraight:
            return LiveGuidance(pill: Copy.phoneNotStraight, tip: Copy.phoneNotStraightTip)
        case .tilted:
            return LiveGuidance(pill: Copy.phoneTilted, tip: Copy.phoneTiltedTip)
        case .specs:
            return LiveGuidance(pill: Copy.removeGlasses, tip: Copy.removeGlassesTip)
        case .faceCovered:
            return LiveGuidance(pill: Copy.faceCovered, tip: Copy.faceCoveredTip)
        case .headCovered:
            return LiveGuidance(pill: Copy.removeCap, tip: Copy.removeCapTip)
        case .bothEyesClosed, .oneEyeClosed:
            return LiveGuidance(pill: Copy.eyesClosed, tip: Copy.eyesClosedTip)
        case .noTeeth:
            return LiveGuidance(pill: Copy.closeMouth, tip: Copy.closeMouthTip)
        case .smiling:
            return LiveGuidance(pill: Copy.noSmile, tip: Copy.noSmileTip)
        case .faceTooClose:
            return LiveGuidance(pill: Copy.tooClose, tip: Copy.tooCloseTip)
        case .faceTooFar:
            return LiveGuidance(pill: Copy.tooFar, tip: Copy.tooFarTip)
        case .faceNotCentered:
            return LiveGuidance(pill: Copy.notCentered, tip: Copy.notCenteredTip)
        case .faceOutOfBounds:
            return LiveGuidance(pill: Copy.faceOutOfFrame, tip: Copy.faceOutOfFrameTip)
        case .faceUp, .faceDown, .faceLeft, .faceRight:
            return LiveGuidance(pill: Copy.lookStraight, tip: Copy.lookStraightTip)
        case .autoCapturing, .faceMissing, .goodPhoto:
            return nil
        }
    }

    private var selfiePill: SelfiePill? {
        if isCompleting {
            return SelfiePill(text: IDCStrings.Capture.perfect, tone: .capturing)
        }
        guard isLiveCamera else { return nil }
        if let guidance = liveGuidance {
            return SelfiePill(
                text: guidance.pill,
                tone: .alert,
                systemIcon: "exclamationmark.circle.fill"
            )
        }
        if isGoodFrame {
            return SelfiePill(text: IDCStrings.SelfieGuidance.holdStill, tone: .capturing)
        }
        return nil
    }

    @ViewBuilder
    private var subStatusLine: some View {
        if let subStatus = selfieSubStatus {
            Text(subStatus.text)
                .typoGraphy(.B1InterMedium14)
                .foregroundStyle(subStatus.color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        } else {
            Color.clear.frame(height: 0)
        }
    }

    private var selfieSubStatus: (text: String, color: Color)? {
        guard isLiveCamera else { return nil }
        if let guidance = liveGuidance {
            return (guidance.tip, IDCTheme.Colors.failureDocumentAccent)
        }
        if isGoodFrame { return nil }
        return (IDCStrings.SelfieGuidance.centerFace, Color.neutralGrey500)
    }

    private var isConfirming: Bool {
        if case .confirming = viewModel.phase { return true }
        return false
    }

    private var frozenImage: UIImage? {
        viewModel.result(for: piece)?.image
    }

    private var cameraFlipButton: some View {
        Button {
            cameraPosition = (cameraPosition == .front) ? .back : .front
        } label: {
            IDCIcon(ATIcon.SwiftUIImage.switchCamera, size: 24)
                .foregroundStyle(Color.pureBlack)
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.pureWhite))
                .overlay(Circle().stroke(Color.pureBlack.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.idcHaptic)
        .accessibilityLabel(IDCStrings.A11y.flipCamera)
    }

    private var bottomArea: some View {
        IDCCaptureFooter(
            state: footerState,
            showsUpload: viewModel.configuration.allowUploadFromDevice,
            skipTitle: viewModel.showsSkip ? viewModel.configuration.skip?.title : nil,
            onUpload: { presentUploadSourceSheet() },
            onRetry: { viewModel.retryTransport(piece) },
            onSkip: { viewModel.skip() },
            minHeight: viewModel.configuration.footerMinHeight
        )
    }

    private var footerState: IDCCaptureFooter.State {
        switch viewModel.phase {
        case .verifying(let current) where current == piece:
            if case .transportFailed(let message) = viewModel.status(for: piece) {
                return .retry(message: message)
            }
            return viewModel.showsVerifiedBeat
                ? .verified(caption: IDCStrings.Footer.uploaded)
                : .verifying(caption: IDCStrings.Footer.uploading)
        default:
            if checkingUpload != nil || frozenImage != nil {
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
        capturedMirrored = false
        checkingUpload = image
        engineHolder.engine.validateUpload(image) { failure in
            checkingUpload = nil
            if let failure {
                viewModel.captureFailed(piece, failure: failure, image: image)
            } else {
                viewModel.captured(piece, image: image, fieldDetections: nil, source: .gallery)
            }
        }
    }
}

private struct IDCSelfieCameraView: View {
    @ObservedObject var cameraService: IDCCameraService
    @Binding var isGoodFrame: Bool
    @Binding var captureProgress: Double
    @Binding var statusMessage: String
    let engine: IDCSelfieScanEngine
    let position: IDCCameraService.CameraPosition
    let onCaptured: (UIImage) -> Void
    var onFaceSeen: () -> Void = {}

    @StateObject private var scanState = IDCSelfieScanState()
    @State private var lastHapticStep = 0

    var body: some View {
        ZStack {
            IDCCameraPreview(session: cameraService.session) { view in
                cameraService.previewView = view
                engine.viewFinderView = view
            }

            if scanState.isGoodFrame {
                IDCHoldStillPreviewTint()
                    .transition(.opacity)
            }

            if let countdown = scanState.countdownNumber {
                Text("\(countdown)")
                    .typoGraphy(.H1InterSemibold36)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pureBlack)
        .animation(.easeInOut(duration: 0.25), value: scanState.isGoodFrame)
        .onAppear {
            engine.startLive(isFrontCamera: position == .front, state: scanState)
            statusMessage = scanState.statusMessage
            weak let liveEngine = engine
            cameraService.configureForVideo(position: position) { sampleBuffer in
                liveEngine?.processFrame(sampleBuffer)
            } onConfigured: {
                cameraService.startSession()
            }
        }
        .onDisappear {
            cameraService.stopSession()
            engine.stopLive()
        }
        .onReceive(scanState.$capturedImage.compactMap { $0 }) { image in
            cameraService.stopSession()
            onCaptured(image)
        }
        .onReceive(scanState.$isGoodFrame) { good in
            isGoodFrame = good
        }
        .onReceive(scanState.$hasSeenFace.filter { $0 }) { _ in
            onFaceSeen()
        }
        .onReceive(scanState.$captureProgress) { progress in
            captureProgress = progress
            tickRatchet(for: progress)
        }
        .onReceive(scanState.$statusMessage) { message in
            statusMessage = message
        }
        .onChange(of: position) { _, newPosition in
            lastHapticStep = 0
            captureProgress = 0
            isGoodFrame = false
            engine.restartLive(isFrontCamera: newPosition == .front)
            weak let liveEngine = engine
            cameraService.switchVideoCapturePosition(to: newPosition) { sampleBuffer in
                liveEngine?.processFrame(sampleBuffer)
            }
            statusMessage = scanState.statusMessage
        }
    }

    private func tickRatchet(for progress: Double) {
        let steps = 10
        let step = Int(progress * Double(steps))
        if step > lastHapticStep {
            if progress < 1 { IDCHaptics.tick() }
        }
        lastHapticStep = step
    }
}

struct IDCSelfieCompletionOverlay: View {
    let image: UIImage
    var mirrored: Bool = false
    var onFinished: () -> Void = {}

    @State private var progress: CGFloat = 0
    @State private var done = false
    @State private var started = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                    .frame(width: w, height: h)
                    .clipped()
                    .blur(radius: done ? 6 : 0)

                if !done {
                    Color.green.opacity(0.25)
                        .frame(height: progress * h)
                        .frame(maxHeight: .infinity, alignment: .top)

                    Rectangle()
                        .fill(Color.green)
                        .frame(height: 2)
                        .shadow(color: .green, radius: 6)
                        .position(x: w / 2, y: progress * h)
                }

                if done {
                    Color.green.opacity(0.12)
                }
            }
            .frame(width: w, height: h)
        }
        .task { await run() }
    }

    private func run() async {
        guard !started else { return }
        started = true
        withAnimation(.easeInOut(duration: IDCTheme.Animation.selfieCompletionDuration)) { progress = 1 }
        try? await Task.sleep(nanoseconds: UInt64(IDCTheme.Animation.selfieCompletionHold * 1_000_000_000))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: IDCTheme.Animation.selfieCompletionReveal)) { done = true }
        IDCHaptics.thump()
        try? await Task.sleep(nanoseconds: UInt64(IDCTheme.Animation.selfieCompletionFinishHold * 1_000_000_000))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}

#if DEBUG
#Preview("Verifying (PERFECT! → Uploading)") {
    IDCSelfieScanScreen(viewModel: IDCPreviewSupport.selfieVerifying())
}

#Preview("Rejection → failure sheet") {
    IDCFlowView(viewModel: IDCPreviewSupport.selfieInlineFailure())
}

#Preview("Live guidance copy") {
    let messages: [IDCSelfieGuidance] = [
        .tooDark, .tooBright, .multipleFaces, .holdStraight, .tilted, .specs,
        .faceCovered, .headCovered, .bothEyesClosed, .noTeeth, .faceTooClose,
        .faceTooFar, .faceNotCentered, .faceOutOfBounds, .faceUp
    ]
    return ScrollView {
        VStack(spacing: 18) {
            ForEach(messages, id: \.rawValue) { message in
                if let guidance = IDCSelfieScanScreen.guidance(for: message) {
                    VStack(spacing: 6) {
                        IDCStatusPill(
                            text: guidance.pill,
                            tone: .alert,
                            systemIcon: "exclamationmark.circle.fill"
                        )
                        Text(guidance.tip)
                            .typoGraphy(.B1InterMedium14)
                            .foregroundStyle(IDCTheme.Colors.failureDocumentAccent)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 200)
                        Text(message.rawValue)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    .background(IDCTheme.Colors.screenBackground)
}

#Preview("Completion overlay") {
    IDCSelfieCompletionOverlay(image: IDCPreviewSupport.sampleImage(label: "Selfie", size: CGSize(width: 500, height: 500), tint: .systemTeal))
        .clipShape(Circle())
        .frame(width: 300, height: 300)
        .padding()
}

#endif
