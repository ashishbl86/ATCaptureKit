import ATUIKit
import SwiftUI

public struct IDCFlowView: View {

    @ObservedObject var viewModel: IDCFlowViewModel

    public init(viewModel: IDCFlowViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        content
            .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
            .onAppear {
                viewModel.onAppear()
                presentReviewSheetIfNeeded(viewModel.confirmingResult)
                presentFailureSheetIfNeeded(viewModel.failureSheetInfo)
            }
            .onChange(of: viewModel.confirmingResult?.id) {
                presentReviewSheetIfNeeded(viewModel.confirmingResult)
            }
            .onChange(of: viewModel.failureSheetInfo) { _, info in
                presentFailureSheetIfNeeded(info)
            }
    }

    private func presentReviewSheetIfNeeded(_ result: IDCCaptureResult?) {
        guard let result else { return }
        IDCPreviewSheet.present(
            result: result,
            onDismiss: { viewModel.cancelCapture() },
            onReupload: viewModel.configuration.allowUploadFromDevice ? {
                viewModel.reuploadFromDevice(result.piece)
                ATBottomSheetWindowPresenter.dismiss()
            } : nil,
            onContinue: {
                viewModel.confirmCapture()
                ATBottomSheetWindowPresenter.dismiss()
            }
        )
    }

    private func presentFailureSheetIfNeeded(_ info: IDCFlowViewModel.FailureSheetInfo?) {
        guard let info else { return }
        IDCHaptics.sheet()
        ATBottomSheetWindowPresenter.present(
            cornerRadius: IDCTheme.Sheet.cornerRadius,
            dimmedBackdropOpacity: IDCTheme.Sheet.darkBackdropOpacity,
            dragToDismiss: true,
            onDismiss: { viewModel.dismissFailureSheet() }
        ) {
            IDCFailureSheet(
                piece: info.piece,
                failure: info.failure,
                image: info.image,
                onReupload: {
                    ATBottomSheetWindowPresenter.dismiss()
                    viewModel.reuploadFromDevice(info.piece)
                },
                onRescan: {
                    ATBottomSheetWindowPresenter.dismiss()
                    viewModel.rescanLive(info.piece)
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .capturing(let piece), .detecting(let piece), .flipping(let piece),
             .confirming(let piece), .verifying(let piece):
            screen(for: piece)
        case .review, .done:
            IDCReviewView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func screen(for piece: IDCPiece) -> some View {
        if piece == .selfie {
            IDCSelfieScanScreen(viewModel: viewModel)
        } else {
            IDCPassportScanScreen(viewModel: viewModel, piece: piece)
        }
    }
}

#if DEBUG
#Preview("Flow at verifying") {
    IDCFlowView(viewModel: IDCPreviewSupport.verifyingPassport())
}

#Preview("Flow at review") {
    IDCFlowView(viewModel: IDCPreviewSupport.reviewMixed())
}

#Preview("Flow with gallery confirm sheet") {
    IDCFlowView(viewModel: IDCPreviewSupport.viewModel(seed: { vm in
        let result = IDCPreviewSupport.passportResult(.passportFront, source: .gallery)
        vm.seedForPreview(
            phase: .confirming(.passportFront),
            results: [.passportFront: result],
            statuses: [.passportFront: .captured]
        )
    }))
}

#Preview("Flow with failure sheet") {
    IDCFlowView(viewModel: IDCPreviewSupport.viewModel(seed: { vm in
        vm.seedForPreview(phase: .capturing(.passportFront))
        vm.failureSheetInfo = IDCFlowViewModel.FailureSheetInfo(
            piece: .passportFront,
            failure: .invalidPassport,
            image: IDCPreviewSupport.sampleImage(label: "Upload")
        )
    }))
}
#endif
