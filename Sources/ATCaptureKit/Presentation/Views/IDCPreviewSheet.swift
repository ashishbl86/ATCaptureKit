import ATUIKit
import SwiftUI
import UIKit

struct IDCPreviewSheet: View {
    let result: IDCCaptureResult
    var ctaTitle: String = IDCStrings.CTA.continue
    let onContinue: () -> Void
    var onReupload: (() -> Void)?

    private var title: String { IDCStrings.Preview.reviewPhoto }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .typoGraphy(.T2InterBold12)
                .textCase(.uppercase)
                .foregroundStyle(Color.pureBlack)
                .padding(.top, 36)

            Rectangle()
                .fill(Color.borderLightLight100)
                .frame(height: 1)
                .padding(.top, 25)
                .padding(.horizontal, 30)

            imageCard
                .padding(.horizontal, 30)
                .padding(.top, 30)

            Rectangle()
                .fill(Color.borderLightLight100)
                .frame(height: 1)
                .padding(.top, 30)
                .padding(.horizontal, 30)

            ATButton(ctaTitle, variant: .primary, colorStyle: .black) {
                IDCHaptics.tap()
                onContinue()
            }
            .padding(.top, 30)
            .padding(.horizontal, 24)

            if let onReupload {
                Text(IDCStrings.CTA.or)
                    .typoGraphy(.T1InterBold11)
                    .tracking(0.88)
                    .foregroundStyle(Color.neutralGrey400)
                    .padding(.top, 16)

                ATButton(
                    IDCStrings.CTA.reupload,
                    variant: .outlineSubtle,
                    colorStyle: .black,
                    inlineIcon: { IDCIcon(ATIcon.SwiftUIImage.upload, size: 16) },
                    action: {
                        IDCHaptics.tap()
                        onReupload()
                    }
                )
                .padding(.top, 16)
                .padding(.horizontal, 24)
            }

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
        .background(Color.pureWhite)
    }

    static func present(
        result: IDCCaptureResult,
        ctaTitle: String = IDCStrings.CTA.continue,
        onDismiss: (() -> Void)? = nil,
        onReupload: (() -> Void)? = nil,
        onContinue: @escaping () -> Void
    ) {
        IDCHaptics.sheet()
        ATBottomSheetWindowPresenter.present(
            cornerRadius: IDCTheme.Sheet.cornerRadius,
            dimmedBackdropOpacity: IDCTheme.Sheet.darkBackdropOpacity,
            dragToDismiss: true,
            onDismiss: onDismiss
        ) {
            IDCPreviewSheet(result: result, ctaTitle: ctaTitle, onContinue: onContinue, onReupload: onReupload)
        }
    }

    private var imageCard: some View {
        Color.clear
            .aspectRatio(380 / 313.7, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                Image(uiImage: result.image)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(
                RoundedRectangle(cornerRadius: IDCTheme.Layout.viewfinderCornerRadius, style: .continuous)
            )
    }
}

#if DEBUG
#Preview("Preview sheet (front page)") {
    IDCPreviewSheet(result: IDCPreviewSupport.passportResult(.passportFront)) {}
}

#Preview("Preview sheet (selfie)") {
    IDCPreviewSheet(result: IDCPreviewSupport.selfieResult()) {}
}

#Preview("Review sheet with re-upload") {
    IDCPreviewSheet(
        result: IDCPreviewSupport.passportResult(.passportFront),
        onContinue: {},
        onReupload: {}
    )
}

#endif
