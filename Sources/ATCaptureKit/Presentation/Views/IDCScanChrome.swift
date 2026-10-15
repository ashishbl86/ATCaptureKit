import ATUIKit
import SwiftUI
import UIKit

struct IDCIcon: View {
    let image: Image
    var size: CGFloat = 18

    init(_ image: Image, size: CGFloat = 18) {
        self.image = image
        self.size = size
    }

    var body: some View {
        image
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

struct IDCAssetIcon: View {
    let image: Image
    var size: CGFloat = 18

    init(_ image: Image, size: CGFloat = 18) {
        self.image = image
        self.size = size
    }

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

struct IDCCoinIcon: View {
    enum Content {
        case asset(Image)
        case template(Image, tint: Color)
    }

    let content: Content
    var coinDiameter: CGFloat = 48
    var iconSize: CGFloat = 26
    var backgroundColor: Color = .white
    var showsShadow: Bool = true

    init(
        asset icon: Image,
        coinDiameter: CGFloat = 48,
        iconSize: CGFloat = 26,
        backgroundColor: Color = .white,
        showsShadow: Bool = true
    ) {
        self.content = .asset(icon)
        self.coinDiameter = coinDiameter
        self.iconSize = iconSize
        self.backgroundColor = backgroundColor
        self.showsShadow = showsShadow
    }

    init(
        template icon: Image,
        tint: Color,
        coinDiameter: CGFloat = 48,
        iconSize: CGFloat = 26,
        backgroundColor: Color = .white,
        showsShadow: Bool = true
    ) {
        self.content = .template(icon, tint: tint)
        self.coinDiameter = coinDiameter
        self.iconSize = iconSize
        self.backgroundColor = backgroundColor
        self.showsShadow = showsShadow
    }

    var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: coinDiameter, height: coinDiameter)
            .shadow(color: showsShadow ? .black.opacity(0.12) : .clear, radius: 8, y: 2)
            .overlay { iconView }
    }

    @ViewBuilder
    private var iconView: some View {
        switch content {
        case let .asset(icon):
            IDCAssetIcon(icon, size: iconSize)
        case let .template(icon, tint):
            IDCIcon(icon, size: iconSize)
                .foregroundStyle(tint)
        }
    }
}

struct IDCDisclaimerIcon: View {
    var coinDiameter: CGFloat = 48
    var iconSize: CGFloat = 32
    var backgroundColor: Color = Color.accentRed50
    var showsShadow: Bool = false

    var body: some View {
        IDCCoinIcon(
            asset: ATIcon.SwiftUIImage.reportProblem,
            coinDiameter: coinDiameter,
            iconSize: iconSize,
            backgroundColor: backgroundColor,
            showsShadow: showsShadow
        )
    }
}

struct IDCErrorBadge: View {
    var coinDiameter: CGFloat = 48
    var markSize: CGFloat = 26
    var backgroundColor: Color = .white
    var showsShadow: Bool = true

    var body: some View {
        IDCCoinIcon(
            asset: ATIcon.SwiftUIImage.error,
            coinDiameter: coinDiameter,
            iconSize: markSize,
            backgroundColor: backgroundColor,
            showsShadow: showsShadow
        )
    }
}

struct IDCScanTopBarTopSpacing: ViewModifier {
    let basePadding: CGFloat
    let includesSafeAreaTop: Bool

    func body(content: Content) -> some View {
        if includesSafeAreaTop {
            content.safeAreaPadding(.top, basePadding)
        } else {
            content.padding(.top, basePadding)
        }
    }
}

extension View {
    func idcScanTopBarTopSpacing(basePadding: CGFloat, includesSafeAreaTop: Bool) -> some View {
        modifier(IDCScanTopBarTopSpacing(basePadding: basePadding, includesSafeAreaTop: includesSafeAreaTop))
    }
}

struct IDCScanTopBar: View {
    let title: String?
    let progress: IDCProgressStyle
    var showsBack: Bool = true
    var onBack: () -> Void = {}
    var trailingSystemImage: String?
    var onTrailingTap: (() -> Void)?

    private var hasCaption: Bool {
        if let title, !title.isEmpty { return true }
        if case .segments = progress { return true }
        if case .fraction = progress { return true }
        return false
    }

    private var hasControls: Bool {
        showsBack || (trailingSystemImage != nil && onTrailingTap != nil)
    }

    var body: some View {
        VStack(spacing: 8) {
            if let title, !title.isEmpty {
                Text(title)
                    .typoGraphy(.T1InterBold11)
                    .tracking(0.88)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.pureBlack)
            }
            if case .segments(let count, let filled) = progress {
                IDCSegmentedProgress(count: count, filled: filled)
                    .frame(width: 80)
            }
            if case .fraction(let value) = progress {
                IDCFractionProgress(value: value)
                    .frame(width: 80)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: (!hasCaption && hasControls) ? IDCTheme.Layout.scanTopBarControlSize : nil)
        .overlay(alignment: .leading) {
            if showsBack {
                Button(action: onBack) {
                    IDCIcon(ATIcon.SwiftUIImage.chevronLeft, size: 24)
                        .foregroundStyle(Color.pureBlack)
                        .frame(width: IDCTheme.Layout.scanTopBarControlSize, height: IDCTheme.Layout.scanTopBarControlSize)
                        .overlay(Circle().stroke(Color.pureBlack.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.idcHaptic)
                .accessibilityLabel(IDCStrings.A11y.back)
            }
        }
        .overlay(alignment: .trailing) {
            if let trailingSystemImage, let onTrailingTap {
                Button(action: onTrailingTap) {
                    IDCIcon(Image(systemName: trailingSystemImage), size: 24)
                        .foregroundStyle(Color.pureBlack)
                        .frame(width: IDCTheme.Layout.scanTopBarControlSize, height: IDCTheme.Layout.scanTopBarControlSize)
                        .overlay(Circle().stroke(Color.pureBlack.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.idcHaptic)
            }
        }
    }
}

struct IDCSegmentedProgress: View {
    let count: Int
    let filled: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Capsule()
                    .fill(index < filled ? Color.pureBlack : Color.neutralGrey100)
                    .frame(height: 3)
            }
        }
    }
}

struct IDCFractionProgress: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.neutralGrey100)
                Capsule()
                    .fill(Color.pureBlack)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 3)
        .animation(.easeInOut(duration: 0.25), value: value)
    }
}

struct IDCCaptureHeader: View {
    enum Icon { case asset(String); case system(String); case image(Image) }

    let icon: Icon
    let title: String
    let subtitle: String
    var highlightFrom: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            iconView
                .foregroundStyle(Color.pureBlack)

            Text(title)
                .typoGraphy(.H5InterMedium20)
                .foregroundStyle(Color.pureBlack)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 15)

            IDCGradientHighlightText(leading: subtitleParts.leading, highlight: subtitleParts.highlight)
                .frame(maxWidth: 240)
                .padding(.top, 15)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .asset(let name):
            Image(name).renderingMode(.template).resizable().scaledToFit().frame(width: 20, height: 20)
        case .system(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        case .image(let image):
            IDCIcon(image, size: 20)
        }
    }

    private var subtitleParts: (leading: String, highlight: String) {
        guard let marker = highlightFrom, let range = subtitle.range(of: marker) else {
            return (subtitle, "")
        }
        return (String(subtitle[..<range.lowerBound]), String(subtitle[range.lowerBound...]))
    }
}

struct IDCGradientHighlightText: View {
    let leading: String
    let highlight: String
    var baseColor: Color = Color.neutralGrey400

    @State private var reveal: CGFloat = 0
    @State private var settled = false

    private static let stops: [Gradient.Stop] = [
        .init(color: Color(hex: "999999"), location: 0.0),
        .init(color: Color(hex: "999999"), location: 0.164),
        .init(color: Color(hex: "5057EA"), location: 0.303),
        .init(color: Color(hex: "D946EF"), location: 0.463),
        .init(color: Color(hex: "EF4444"), location: 0.749),
        .init(color: Color(hex: "EDD758"), location: 1.0),
    ]

    var body: some View {
        styled(text(highlightOnly: false))
            .overlay {
                if !highlight.isEmpty {
                    LinearGradient(stops: Self.stops, startPoint: .leading, endPoint: .trailing)
                        .mask(styled(text(highlightOnly: true)))
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle()
                                    .frame(width: geo.size.width * reveal)
                            }
                        }
                        .opacity(settled ? 0 : 1)
                        .allowsHitTesting(false)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .task {
                guard !highlight.isEmpty else { return }
                withAnimation(.easeInOut(duration: IDCTheme.Animation.gradientSubtitleReveal)) {
                    reveal = 1
                }
                try? await Task.sleep(nanoseconds: IDCTheme.Animation.gradientSubtitleHoldNanoseconds)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: IDCTheme.Animation.gradientSubtitleSettle)) {
                    settled = true
                }
            }
    }

    private func text(highlightOnly: Bool) -> Text {
        var lead = AttributedString(leading)
        lead.foregroundColor = highlightOnly ? .clear : baseColor
        var hi = AttributedString(highlight)
        hi.foregroundColor = highlightOnly ? .black : baseColor
        lead.append(hi)
        return Text(lead)
    }

    private func styled(_ text: Text) -> some View {
        text
            .typoGraphy(.B1InterMedium14)
            .multilineTextAlignment(.center)
    }
}

struct IDCScanViewfinder<Content: View>: View {
    var caption: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 16) {
            if let caption {
                Text(caption)
                    .typoGraphy(.T2InterBold12)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.pureBlack)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension View {
    func idcViewfinderSurface() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pureBlack)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: IDCTheme.Layout.viewfinderCornerRadius,
                    style: .continuous
                )
            )
    }
}

struct IDCHoldStillPreviewTint: View {
    var body: some View {
        LinearGradient.idcHoldStillWash
            .allowsHitTesting(false)
    }
}

struct IDCStatusPill: View {
    enum Tone { case coaching, ready, alert, capturing }

    let text: String
    let tone: Tone
    var systemIcon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(text)
                .typoGraphy(.T1InterBold11)
                .tracking(0.88)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, IDCTheme.Layout.statusPillHorizontalPadding)
        .padding(.vertical, IDCTheme.Layout.statusPillVerticalPadding)
        .background(Capsule().fill(background))
    }

    private var foreground: Color {
        switch tone {
        case .coaching: return IDCTheme.Colors.statusCoachingForeground
        case .ready: return IDCTheme.Colors.statusReadyForeground
        case .alert: return IDCTheme.Colors.statusAlertForeground
        case .capturing: return IDCTheme.Colors.statusCapturingForeground
        }
    }

    private var background: Color {
        switch tone {
        case .coaching: return IDCTheme.Colors.statusCoachingBackground
        case .ready: return IDCTheme.Colors.statusReadyBackground
        case .alert: return IDCTheme.Colors.statusAlertBackground
        case .capturing: return IDCTheme.Colors.statusCapturingBackground
        }
    }
}

struct IDCCaptureFooter: View {
    enum State: Equatable {
        case idle
        case disabled
        case verifying(caption: String)
        case verified(caption: String)
        case retry(message: String)
    }

    var state: State = .idle
    var showsUpload: Bool = true
    var showsReminderLink: Bool = false
    var skipTitle: String?
    var onUpload: () -> Void = {}
    var onRetry: () -> Void = {}
    var onReminderTap: () -> Void = {}
    var onSkip: () -> Void = {}
    var minHeight: CGFloat = IDCTheme.Layout.footerMinHeight

    var body: some View {
        ZStack {
            switch state {
            case .idle, .disabled:
                controls
                    .opacity(state == .disabled ? 0.4 : 1)
                    .disabled(state == .disabled)
            case .verifying(let caption):
                VStack(spacing: 24) {
                    IDCVerifyingDots()
                    Text(caption)
                        .typoGraphy(.B1InterSemibold14)
                        .foregroundStyle(Color.pureBlack)
                }
                .transition(.opacity)
            case .verified(let caption):
                VStack(spacing: 12) {
                    IDCVerifiedSeal()
                    Text(caption)
                        .typoGraphy(.B2InterBold12)
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.pureBlack)
                }
                .transition(.opacity)
            case .retry(let message):
                VStack(spacing: 10) {
                    Text(IDCStrings.Failure.connectionErrorTitle)
                        .typoGraphy(.H7InterSemibold16)
                        .foregroundStyle(IDCTheme.Colors.failureDocumentAccent)
                    Text(message)
                        .typoGraphy(.B1InterMedium14)
                        .foregroundStyle(Color.neutralGrey500)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    retryButton
                        .padding(.top, 20)
                }
            }
        }
        .frame(minHeight: minHeight)
    }

    private var controls: some View {
        VStack(spacing: 24) {
            if showsUpload {
                Button {
                    IDCHaptics.tap()
                    onUpload()
                } label: {
                    IDCIcon(ATIcon.SwiftUIImage.collections, size: 24)
                        .foregroundStyle(Color.pureBlack)
                        .frame(width: 55, height: 55)
                        .overlay(Circle().stroke(Color.borderLightLight200, lineWidth: 1))
                }
                .buttonStyle(.idcHaptic)
                .accessibilityLabel(IDCStrings.CTA.uploadFromDevice)
            }

            if let skipTitle {
                Button {
                    IDCHaptics.tap()
                    onSkip()
                } label: {
                    Text(skipTitle)
                        .typoGraphy(.B1InterSemibold14)
                        .underline()
                        .foregroundStyle(Color.neutralGrey500)
                }
                .buttonStyle(.idcHaptic)
                .transition(.opacity)
            }

            if showsReminderLink {
                Button {
                    IDCHaptics.tap()
                    onReminderTap()
                } label: {
                    Text(IDCStrings.Reminder.dontHaveItHandy)
                        .typoGraphy(.B1InterSemibold14)
                        .underline()
                        .foregroundStyle(Color.pureBlack)
                }
                .buttonStyle(.idcHaptic)
            }
        }
    }

    private var retryButton: some View {
        ATButton(
            IDCStrings.CTA.retry,
            size: .medium,
            variant: .outlineSubtle,
            colorStyle: .black,
            inlineIcon: { IDCIcon(ATIcon.SwiftUIImage.refresh, size: 18) },
            action: {
                IDCHaptics.tap()
                onRetry()
            }
        )
        .frame(width: IDCTheme.Layout.failureActionWidth)
    }
}

struct IDCVerifyingDots: View {
    var dotSize: CGFloat = 8
    var color: Color = .pureBlack

    @State private var animating = false

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: animating ? -4 : 3)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .frame(height: dotSize + 8)
        .onAppear { animating = true }
    }
}

struct IDCVerifiedSeal: View {
    var diameter: CGFloat = IDCTheme.Badge.verifiedSealDiameter

    var body: some View {
        IDCScallopBadgeShape()
            .fill(Color.pureBlack)
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.42, weight: .bold))
                    .foregroundStyle(Color.pureWhite)
            }
    }
}

struct IDCVerifiedSpinner: View {
    var dotCount: Int = 8
    var dotScale: CGFloat = 0.16

    @State private var appeared = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let dot = side * dotScale
                let radius = (side - dot) / 2
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ForEach(0..<dotCount, id: \.self) { index in
                    let angle = (Double(index) / Double(dotCount)) * 2 * .pi - .pi / 2
                    Circle()
                        .fill(IDCTheme.Colors.verifiedSpinnerDot)
                        .frame(width: dot, height: dot)
                        .position(
                            x: center.x + radius * CGFloat(cos(angle)),
                            y: center.y + radius * CGFloat(sin(angle))
                        )
                }
            }
            .rotationEffect(.degrees(appeared ? 90 : 0))

            IDCIcon(ATIcon.SwiftUIImage.check, size: 16)
                .foregroundStyle(Color.pureBlack)
                .scaleEffect(appeared ? 1 : 0.4)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
        }
    }
}

struct IDCProcessingStill: View {
    let image: UIImage
    var mirrored: Bool = false

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Color.black.opacity(0.35)

            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
        }
    }
}

#Preview("Coin badges") {
    VStack(spacing: 24) {
        HStack(spacing: 32) {
            IDCErrorBadge(coinDiameter: 42, markSize: 26)
            IDCDisclaimerIcon(coinDiameter: 48, iconSize: 32)
            IDCErrorBadge(coinDiameter: 64, markSize: 42)
        }
        IDCDisclaimerIcon(
            coinDiameter: 64,
            iconSize: 28,
            backgroundColor: Color.accentAmber50
        )
    }
    .padding()
}

#Preview("Top bar + pills") {
    VStack(spacing: 28) {
        IDCScanTopBar(title: "[Title text here]", progress: .segments(count: 4, filled: 1))
        IDCStatusPill(text: "Align face in frame", tone: .coaching)
        IDCStatusPill(text: "Hold still", tone: .ready)
        IDCStatusPill(
            text: IDCStrings.PassportGuidance.glareDetected,
            tone: .alert,
            systemIcon: "exclamationmark.circle.fill"
        )
        IDCStatusPill(text: IDCStrings.PassportGuidance.capturing, tone: .capturing)
        IDCVerifiedSpinner().frame(width: 44, height: 44)
        IDCVerifiedSeal()
    }
    .padding()
}

#Preview("Footer states") {
    VStack(spacing: 24) {
        IDCCaptureFooter(state: .idle)
        IDCCaptureFooter(state: .verifying(caption: "Verifying passport"))
        IDCCaptureFooter(state: .verified(caption: "Verified"))
        IDCCaptureFooter(state: .retry(message: "Something went wrong — check your connection."))
    }
    .padding()
}

#if DEBUG
#Preview("Capture header") {
    VStack(spacing: 40) {
        IDCCaptureHeader(
            icon: .asset("kyc_passport_doc"),
            title: "Scan your passport",
            subtitle: "We'll capture when in focus",
            highlightFrom: "capture when in focus"
        )
        IDCCaptureHeader(icon: .system("dot.viewfinder"), title: "Take a selfie", subtitle: "Required by all governments")
    }
    .padding()
}

#Preview("Viewfinder + processing still") {
    IDCScanViewfinder(caption: "FRONT PAGE") {
        IDCProcessingStill(image: IDCPreviewSupport.sampleImage(label: "Front Page"))
            .idcViewfinderSurface()
    }
    .frame(height: 380)
    .padding(20)
}
#endif
