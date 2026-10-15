import CoreImage
import UIKit

enum IDCFrameRenderer {

    struct PassportCapture {
        let image: UIImage
        let isCropped: Bool
    }

    private static let context = CIContext()
    private static let inputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)

    static func passportCapture(_ pixelBuffer: CVPixelBuffer, normalizedRect: CGRect) -> PassportCapture? {
        let upright = uprightImage(pixelBuffer)
        let extent = upright.extent
        let passportRect = CGRect(
            x: normalizedRect.minX * extent.width,
            y: normalizedRect.minY * extent.height,
            width: normalizedRect.width * extent.width,
            height: normalizedRect.height * extent.height
        )
        if let cropRect = pixelRect(passportRect, in: extent),
           let cgImage = context.createCGImage(upright, from: cropRect) {
            return PassportCapture(image: UIImage(cgImage: cgImage), isCropped: true)
        }
        guard let cgImage = context.createCGImage(upright, from: extent) else { return nil }
        return PassportCapture(image: UIImage(cgImage: cgImage), isCropped: false)
    }

    static func selfieCapture(_ pixelBuffer: CVPixelBuffer, viewfinderSize: CGSize) -> UIImage? {
        let upright = uprightImage(pixelBuffer)
        let extent = upright.extent
        let cropRect = pixelRect(centeredRect(in: extent.size, matching: viewfinderSize), in: extent) ?? extent
        guard let cgImage = context.createCGImage(upright, from: cropRect) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func uprightImage(_ pixelBuffer: CVPixelBuffer) -> CIImage {
        var options: [CIImageOption: Any] = [:]
        if let inputColorSpace {
            options[.colorSpace] = inputColorSpace
        }
        return CIImage(cvPixelBuffer: pixelBuffer, options: options).oriented(.right)
    }

    private static func centeredRect(in size: CGSize, matching viewfinderSize: CGSize) -> CGRect {
        guard viewfinderSize.width > 0, viewfinderSize.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let aspect = viewfinderSize.width / viewfinderSize.height
        let width: CGFloat
        let height: CGFloat
        if size.width / size.height > aspect {
            height = size.height
            width = size.height * aspect
        } else {
            width = size.width
            height = size.width / aspect
        }
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private static func pixelRect(_ topLeftRect: CGRect, in extent: CGRect) -> CGRect? {
        let clipped = topLeftRect.intersection(CGRect(origin: .zero, size: extent.size))
        guard !clipped.isNull else { return nil }
        let x = clipped.minX.rounded(.down)
        let y = clipped.minY.rounded(.down)
        let width = clipped.width.rounded(.down)
        let height = clipped.height.rounded(.down)
        guard width > 0, height > 0 else { return nil }
        return CGRect(x: extent.minX + x, y: extent.minY + extent.height - y - height, width: width, height: height)
    }
}
