import ATUIKit
import SwiftUI

struct IDCCoTravellerPhotoSheet: View {
    let name: String
    var flowTitle: String?
    var progress: IDCProgressStyle = .hidden
    let onUpload: () -> Void
    let onCaptureLive: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Text(IDCStrings.CoTraveller.addPhotoTitle(name: name))
                .typoGraphy(.H5InterMedium20)
                .tracking(-0.5)
                .foregroundStyle(Color.pureBlack)
                .multilineTextAlignment(.center)
                .padding(.top, 56)

            Spacer()

            avatar

            Spacer()

            Text(IDCStrings.CoTraveller.message)
                .typoGraphy(.B1InterMedium14)
                .foregroundStyle(Color.neutralGrey500)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            actions
                .padding(.top, 32)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pureWhite.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 10) {
            IDCIcon(ATIcon.SwiftUIImage.personAdd, size: 20)
                .foregroundStyle(Color.pureBlack)

            Text(flowTitle ?? IDCStrings.CoTraveller.defaultFlowTitle)
                .typoGraphy(.T1InterBold11)
                .tracking(0.88)
                .textCase(.uppercase)
                .foregroundStyle(Color.pureBlack)

            if case .segments(let count, let filled) = progress {
                IDCSegmentedProgress(count: count, filled: filled)
                    .frame(width: 80)
            }
        }
        .padding(.top, 32)
    }

    private var avatar: some View {
        Circle()
            .stroke(Color.neutralGrey100, lineWidth: 1)
            .frame(width: 110, height: 110)
            .overlay {
                IDCIcon(ATIcon.SwiftUIImage.face, size: 44)
                    .foregroundStyle(Color.pureBlack)
            }
    }

    private var actions: some View {
        VStack(spacing: 14) {
            ATButton(
                IDCStrings.CoTraveller.uploadPhoto,
                size: .medium,
                variant: .primary,
                colorStyle: .black,
                inlineIcon: { IDCIcon(ATIcon.SwiftUIImage.upload, size: 18) },
                action: {
                    IDCHaptics.tap()
                    onUpload()
                }
            )
            .frame(width: IDCTheme.Layout.failureActionWidth)

            Text(IDCStrings.CTA.or)
                .typoGraphy(.T1InterBold11)
                .tracking(0.88)
                .foregroundStyle(Color.neutralGrey400)

            ATButton(
                IDCStrings.CoTraveller.captureLive,
                size: .medium,
                variant: .outlineSubtle,
                colorStyle: .black,
                inlineIcon: { IDCIcon(ATIcon.SwiftUIImage.cropFree, size: 18) },
                action: {
                    IDCHaptics.tap()
                    onCaptureLive()
                }
            )
            .frame(width: IDCTheme.Layout.failureActionWidth)
        }
    }
}

#if DEBUG
#Preview("Co-traveller photo chooser") {
    Color.pureBlack.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            IDCCoTravellerPhotoSheet(
                name: "Siddhi Bhansali",
                flowTitle: "Identity check",
                progress: .segments(count: 3, filled: 3),
                onUpload: {},
                onCaptureLive: {}
            )
            .presentationDragIndicator(.visible)
        }
}
#endif
