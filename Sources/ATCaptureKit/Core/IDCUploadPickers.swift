import PDFKit
import SwiftUI
import UIKit

struct IDCPhotoPickerSource: Identifiable {
    let type: UIImagePickerController.SourceType

    var id: Int { type.rawValue }
}

enum IDCImportedFile {

    static func image(from data: Data) -> UIImage? {
        if let image = UIImage(data: data) { return image }
        return PDFDocument(data: data)?.page(at: 0)?.asImage()
    }
}

private extension PDFPage {

    func asImage() -> UIImage? {
        guard let page = pageRef else { return nil }

        let pageRect = page.getBoxRect(.artBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)

            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)

            ctx.cgContext.drawPDFPage(page)
        }
    }
}

struct IDCImagePicker: UIViewControllerRepresentable {

    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        private let parent: IDCImagePicker

        init(_ parent: IDCImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
