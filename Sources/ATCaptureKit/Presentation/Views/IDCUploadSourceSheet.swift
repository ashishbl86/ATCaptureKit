import ATUIKit
import SwiftUI
import UIKit

struct IDCUploadSourceSheet: View {

    struct Option: Identifiable {
        let id = UUID()
        let title: String
        let icon: Image
        let action: () -> Void
    }

    let options: [Option]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                Button {
                    IDCHaptics.tap()
                    option.action()
                } label: {
                    row(option)
                }
                .buttonStyle(.idcHaptic)

                if index < options.count - 1 {
                    Rectangle()
                        .fill(Color.borderLightLight100)
                        .frame(height: 1)
                        .padding(.leading, IDCTheme.Layout.uploadSourceRowLabelInset)
                }
            }
        }
        .padding(.horizontal, IDCTheme.Layout.uploadSourceHorizontalPadding)
        .padding(.top, IDCTheme.Layout.uploadSourceTopPadding)
        .padding(.bottom, IDCTheme.Layout.uploadSourceBottomPadding)
        .frame(maxWidth: .infinity)
        .background(Color.pureWhite)
    }

    private func row(_ option: Option) -> some View {
        HStack(spacing: IDCTheme.Layout.uploadSourceIconLabelSpacing) {
            IDCIcon(option.icon, size: IDCTheme.Layout.uploadSourceIconSize)
                .foregroundStyle(Color.pureBlack)
                .frame(
                    width: IDCTheme.Layout.uploadSourceBadgeDiameter,
                    height: IDCTheme.Layout.uploadSourceBadgeDiameter
                )
                .overlay(Circle().stroke(Color.borderLightLight200, lineWidth: 1))

            Text(option.title)
                .typoGraphy(.B1InterSemibold14)
                .foregroundStyle(Color.pureBlack)

            Spacer(minLength: 0)
        }
        .padding(.vertical, IDCTheme.Layout.uploadSourceRowVerticalPadding)
        .contentShape(Rectangle())
    }

    static func present(options: [Option]) {
        guard !options.isEmpty else { return }
        IDCHaptics.sheet()
        ATBottomSheetWindowPresenter.present(
            cornerRadius: IDCTheme.Sheet.cornerRadius,
            dimmedBackdropOpacity: IDCTheme.Sheet.darkBackdropOpacity,
            dragToDismiss: true
        ) {
            IDCUploadSourceSheet(options: options)
        }
    }
}

extension IDCUploadSourceSheet {

    static func presentForCapture(
        onImportFile: @escaping () -> Void,
        onPick: @escaping (UIImagePickerController.SourceType) -> Void
    ) {
        var options: [Option] = []

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            options.append(Option(title: IDCStrings.UploadSource.takePhoto, icon: ATIcon.SwiftUIImage.cameraAlt) {
                dismissThen { onPick(.camera) }
            })
        }

        options.append(Option(title: IDCStrings.UploadSource.chooseFromGallery, icon: ATIcon.SwiftUIImage.collections) {
            dismissThen { onPick(.photoLibrary) }
        })

        options.append(Option(title: IDCStrings.UploadSource.chooseFile, icon: Image(systemName: "folder")) {
            dismissThen(onImportFile)
        })

        present(options: options)
    }

    private static func dismissThen(_ action: @escaping () -> Void) {
        ATBottomSheetWindowPresenter.dismiss()
        DispatchQueue.main.async(execute: action)
    }
}

#if DEBUG
#Preview("Upload source sheet") {
    IDCUploadSourceSheet(options: [
        .init(title: IDCStrings.UploadSource.takePhoto, icon: ATIcon.SwiftUIImage.cameraAlt, action: {}),
        .init(title: IDCStrings.UploadSource.chooseFromGallery, icon: ATIcon.SwiftUIImage.collections, action: {}),
        .init(title: IDCStrings.UploadSource.chooseFile, icon: Image(systemName: "folder"), action: {}),
    ])
}
#endif
