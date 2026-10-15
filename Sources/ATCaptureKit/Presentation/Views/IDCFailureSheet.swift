import ATUIKit
import SwiftUI
import UIKit

struct IDCFailureActionButtons: View {
    let reuploadTitle: String
    let rescanTitle: String
    var reuploadIcon: Image = ATIcon.SwiftUIImage.upload
    var rescanIcon: Image = ATIcon.SwiftUIImage.cropFree
    let onReupload: () -> Void
    let onRescan: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            actionButton(title: reuploadTitle, icon: reuploadIcon, action: onReupload)
            actionButton(title: rescanTitle, icon: rescanIcon, action: onRescan)
        }
    }

    private func actionButton(title: String, icon: Image, action: @escaping () -> Void) -> some View {
        ATButton(
            title,
            variant: .outlineSubtle,
            colorStyle: .black,
            frameMode: .hugContent,
            inlineIcon: { IDCIcon(icon, size: 16) },
            action: {
                IDCHaptics.tap()
                action()
            }
        )
    }
}

struct IDCFailureSheet: View {
    let piece: IDCPiece
    let failure: IDCCaptureFailure
    var image: UIImage? = nil
    let onReupload: () -> Void
    let onRescan: () -> Void

    private var isDocumentCheck: Bool { failure.check == .document }

    private var accent: Color {
        isDocumentCheck ? IDCTheme.Colors.failureDocumentAccent : IDCTheme.Colors.failureQualityAccent
    }

    private var eyebrow: String {
        isDocumentCheck ? IDCStrings.Failure.documentCheckEyebrow : IDCStrings.Failure.qualityCheckEyebrow
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(eyebrow)
                .typoGraphy(.T2InterBold12)
                .textCase(.uppercase)
                .foregroundStyle(Color.pureBlack)
                .padding(.top, 30)

            Rectangle()
                .fill(Color.borderLightLight100)
                .frame(height: 1)
                .padding(.top, 25)
                .padding(.horizontal, 30)

            imageCard
                .padding(.top, 30)
                .padding(.horizontal, 30)

            Text(failure.title)
                .typoGraphy(.H7InterSemibold16)
                .foregroundStyle(accent)
                .multilineTextAlignment(.center)
                .padding(.top, 30)
                .padding(.horizontal, 32)

            Text(failure.message)
                .typoGraphy(.B1InterMedium14)
                .foregroundStyle(Color.neutralGrey500)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 36)

            actions
                .padding(.top, 30)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(Color.pureWhite)
    }

    private var imageCard: some View {
        Color.clear
            .aspectRatio(380 / 313.7, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    IDCTheme.Colors.cardBackground
                }
            }
            .overlay {
                if isDocumentCheck, image != nil {
                    IDCTheme.Colors.failureWashStart.opacity(0.4)
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: IDCTheme.Layout.viewfinderCornerRadius, style: .continuous)
            )
            .overlay { coin }
    }

    private var coin: some View {
        Circle()
            .fill(Color.pureWhite)
            .frame(width: IDCTheme.Badge.failureCoinDiameter, height: IDCTheme.Badge.failureCoinDiameter)
            .overlay {
                IDCIcon(
                    isDocumentCheck ? ATIcon.SwiftUIImage.error : ATIcon.SwiftUIImage.warning,
                    size: IDCTheme.Badge.failureCoinIconSize
                )
                .foregroundStyle(accent)
            }
    }

    @ViewBuilder
    private var actions: some View {
        if isDocumentCheck {
            VStack(spacing: 15) {
                documentAction(title: IDCStrings.CTA.reupload, icon: ATIcon.SwiftUIImage.upload, action: onReupload)
                Text(IDCStrings.CTA.or)
                    .typoGraphy(.T1InterBold11)
                    .tracking(0.88)
                    .foregroundStyle(Color.neutralGrey400)
                documentAction(title: IDCStrings.CTA.scan, icon: ATIcon.SwiftUIImage.cropFree, action: onRescan)
            }
        } else {
            ATButton(
                IDCStrings.CTA.scan,
                size: .small,
                variant: .primary,
                colorStyle: .black,
                inlineIcon: { IDCIcon(ATIcon.SwiftUIImage.cropFree, size: 16) },
                action: {
                    IDCHaptics.tap()
                    onRescan()
                }
            )
        }
    }

    private func documentAction(title: String, icon: Image, action: @escaping () -> Void) -> some View {
        ATButton(
            title,
            size: .small,
            variant: .outlineSubtle,
            colorStyle: .black,
            inlineIcon: { IDCIcon(icon, size: 16) },
            action: {
                IDCHaptics.tap()
                action()
            }
        )
        .frame(width: IDCTheme.Layout.failureActionWidth)
    }
}

struct IDCConnectionErrorOverlay: View {
    let image: UIImage

    var body: some View {
        ZStack {
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .saturation(0)
                }
                .clipped()

            Color.black.opacity(0.41)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.7),
                    .init(color: Color(hex: "EF4444").opacity(0.4), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.pureWhite)
                .frame(
                    width: IDCTheme.Badge.connectionErrorCoinDiameter,
                    height: IDCTheme.Badge.connectionErrorCoinDiameter
                )
                .overlay {
                    IDCIcon(ATIcon.SwiftUIImage.wifiOff, size: IDCTheme.Badge.failureCoinIconSize)
                        .foregroundStyle(Color.pureBlack)
                }
        }
    }
}

#if DEBUG
#Preview("Document check (invalid)") {
    IDCFailureSheet(
        piece: .passportFront,
        failure: .invalidPassport,
        image: IDCPreviewSupport.sampleImage(label: "Upload", tint: .systemPink),
        onReupload: {},
        onRescan: {}
    )
}

#Preview("Quality check (blur)") {
    IDCFailureSheet(
        piece: .passportFront,
        failure: .textHardToRead,
        image: IDCPreviewSupport.sampleImage(label: "Upload"),
        onReupload: {},
        onRescan: {}
    )
}

#Preview("Quality check (glare)") {
    IDCFailureSheet(
        piece: .passportFront,
        failure: .lightReflection,
        image: IDCPreviewSupport.sampleImage(label: "Upload", tint: .systemYellow),
        onReupload: {},
        onRescan: {}
    )
}

#Preview("Failure sheet (selfie)") {
    IDCFailureSheet(
        piece: .selfie,
        failure: .selfieIssue(nil),
        onReupload: {},
        onRescan: {}
    )
}

#Preview("Connection error overlay") {
    IDCConnectionErrorOverlay(image: IDCPreviewSupport.sampleImage(label: "Front Page"))
        .frame(height: 420)
        .background(Color.pureBlack)
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .padding(20)
}

#Preview("Failure action buttons") {
    IDCFailureActionButtons(
        reuploadTitle: IDCStrings.CTA.reuploadFromDevice,
        rescanTitle: IDCStrings.Failure.scanLivePassport,
        onReupload: {},
        onRescan: {}
    )
    .padding(24)
}
#endif
