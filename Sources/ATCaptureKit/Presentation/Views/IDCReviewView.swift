import ATUIKit
import SwiftUI
import UIKit

struct IDCReviewView: View {

    @ObservedObject var viewModel: IDCFlowViewModel

    @State private var previewResult: IDCCaptureResult?

    var body: some View {
        VStack(spacing: 0) {
            IDCScanTopBar(
                title: viewModel.configuration.resolvedFlowTitle,
                progress: viewModel.displayProgress,
                showsBack: viewModel.configuration.showsBack,
                onBack: { viewModel.exit() }
            )
            .padding(.top, IDCTheme.Layout.topBarTopPadding)
            .padding(.horizontal, IDCTheme.Layout.screenHorizontalPadding)

            ScrollView {
                VStack(spacing: 20) {
                    header
                        .padding(.top, IDCTheme.Layout.reviewHeaderTopPadding)

                    ForEach(viewModel.orderedPieces, id: \.self) { piece in
                        card(for: piece)
                    }

                    if viewModel.allPiecesVerified {
                        continueButton
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, IDCTheme.Layout.screenHorizontalPadding)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(IDCTheme.Colors.screenBackground.ignoresSafeArea())
        .onChange(of: previewResult?.id) {
            presentPreviewSheetIfNeeded(previewResult)
        }
    }

    private func presentPreviewSheetIfNeeded(_ result: IDCCaptureResult?) {
        guard let result else { return }
        IDCPreviewSheet.present(
            result: result,
            ctaTitle: IDCStrings.CTA.continue,
            onDismiss: { previewResult = nil },
            onContinue: {
                previewResult = nil
                ATBottomSheetWindowPresenter.dismiss()
            }
        )
    }

    private var anyRejected: Bool {
        viewModel.orderedPieces.contains {
            if case .rejected = viewModel.status(for: $0) { return true }
            return false
        }
    }

    private var header: some View {
        VStack(spacing: 18) {
            if anyRejected {
                IDCDisclaimerIcon(
                    coinDiameter: IDCTheme.Badge.reviewHeaderCoinDiameter,
                    iconSize: IDCTheme.Badge.reviewHeaderIconSize
                )
            } else {
                IDCVerifiedSpinner()
                    .frame(
                        width: IDCTheme.Badge.verifiedSpinnerSize,
                        height: IDCTheme.Badge.verifiedSpinnerSize
                    )
            }
            Text(anyRejected ? IDCStrings.Review.errorHeadline : IDCStrings.Review.allChecksPassed)
                .typoGraphy(.H5InterMedium20)
                .tracking(-0.4)
                .foregroundStyle(Color.pureBlack)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func card(for piece: IDCPiece) -> some View {
        let status = viewModel.status(for: piece)
        let rejected: String? = {
            if case .rejected(let reason) = status { return reason }
            return nil
        }()

        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                thumbnail(for: piece, failed: rejected != nil)

                VStack(alignment: .leading, spacing: 6) {
                    IDCIcon(rejected != nil ? ATIcon.SwiftUIImage.warningAmber : ATIcon.SwiftUIImage.checkCircle, size: 16)
                        .foregroundStyle(rejected != nil ? Color.red : Color.green)

                    Text(piece.displayName)
                        .typoGraphy(.B1InterSemibold14)
                        .tracking(-0.4)
                        .foregroundStyle(Color.pureBlack)

                    Text(rejected ?? IDCStrings.Review.pieceLooksGood)
                        .typoGraphy(.B2InterMedium12)
                        .foregroundStyle(rejected != nil ? Color.red : Color.neutralGrey300)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            IDCDottedDivider()

            if rejected != nil {
                ATButton(
                    IDCStrings.CTA.scanAgain,
                    size: .medium,
                    variant: .primary,
                    colorStyle: .black,
                    inlineIcon: { IDCIcon(ATIcon.SwiftUIImage.cropFree, size: 16) },
                    action: {
                        IDCHaptics.tap()
                        viewModel.rescan(piece)
                    }
                )
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 16) {
                    circleIconButton(ATIcon.SwiftUIImage.edit, label: IDCStrings.A11y.rescan) {
                        viewModel.rescan(piece)
                    }
                    circleIconButton(ATIcon.SwiftUIImage.visibility, label: IDCStrings.A11y.previewCapture) {
                        if let result = viewModel.result(for: piece) { previewResult = result }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(IDCTheme.Layout.previewCardPadding)
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .background(
            RoundedRectangle(cornerRadius: IDCTheme.Layout.reviewCardCornerRadius, style: .continuous)
                .fill(Color.pureWhite)
        )
        .overlay(
            RoundedRectangle(cornerRadius: IDCTheme.Layout.reviewCardCornerRadius, style: .continuous)
                .stroke(rejected != nil ? Color.red.opacity(0.35) : Color.neutralGrey200, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func thumbnail(for piece: IDCPiece, failed: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: IDCTheme.Layout.reviewThumbnailCornerRadius, style: .continuous)
                .fill(IDCTheme.Colors.cardBackground)

            if let image = viewModel.result(for: piece)?.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .grayscale(failed ? 1 : 0)
                    .frame(width: 116, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: IDCTheme.Layout.reviewThumbnailCornerRadius, style: .continuous))
            } else {
                IDCIcon(piece.isPassport ? ATIcon.SwiftUIImage.photo : ATIcon.SwiftUIImage.accountCircle, size: 26)
                    .foregroundStyle(Color.neutralGrey300)
            }

            if failed {
                IDCErrorBadge(
                    coinDiameter: IDCTheme.Badge.reviewThumbnailCoinDiameter,
                    markSize: IDCTheme.Badge.reviewThumbnailMarkSize
                )
            }
        }
        .frame(width: 130, height: 90)
    }

    private func circleIconButton(_ icon: Image, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            IDCIcon(icon, size: 17)
                .foregroundStyle(Color.pureBlack)
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(Color.neutralGrey50, lineWidth: 1))
        }
        .buttonStyle(.idcHaptic)
        .accessibilityLabel(label)
    }

    private var continueButton: some View {
        ATButton(IDCStrings.CTA.continue, variant: .primary, colorStyle: .black) {
            IDCHaptics.tap()
            viewModel.reviewContinue()
        }
    }
}

#if DEBUG
#Preview("Mixed (one rejected)") {
    IDCReviewView(viewModel: IDCPreviewSupport.reviewMixed())
}

#Preview("All verified") {
    IDCReviewView(viewModel: IDCPreviewSupport.reviewAllVerified())
}
#endif
