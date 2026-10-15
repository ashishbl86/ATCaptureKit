import Accelerate
import CoreVideo
import UIKit

enum IDCAnalysisError: Error {
    case modelNotReady
    case unexpectedTensor
    case imageConversion
}

enum IDCPixelBuffers {

    private static let laplacian: [Float] = [-1, -1, -1,
                                             -1, 8, -1,
                                             -1, -1, -1]

    static func size(of pixelBuffer: CVPixelBuffer) -> CGSize {
        CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
    }

    static func vImageBuffer(of pixelBuffer: CVPixelBuffer) throws -> vImage_Buffer {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw IDCAnalysisError.imageConversion
        }
        return vImage_Buffer(
            data: baseAddress,
            height: UInt(CVPixelBufferGetHeight(pixelBuffer)),
            width: UInt(CVPixelBufferGetWidth(pixelBuffer)),
            rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer)
        )
    }

    static func crop(_ pixelBuffer: CVPixelBuffer, to rect: CGRect) -> CVPixelBuffer? {
        let bufferBounds = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let rect = rect.intersection(bufferBounds)
        guard !rect.isEmpty else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let inputRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let channels = 4
        let startPosition = Int(rect.origin.y) * inputRowBytes + channels * Int(rect.origin.x)
        let outWidth = UInt(rect.width)
        let outHeight = UInt(rect.height)
        let croppedRowBytes = Int(outWidth) * channels

        guard let croppedBytes = malloc(Int(outHeight) * croppedRowBytes) else { return nil }

        vDSP_mmov(
            baseAddress.advanced(by: startPosition).assumingMemoryBound(to: Float32.self),
            croppedBytes.assumingMemoryBound(to: Float32.self),
            vDSP_Length(outWidth),
            vDSP_Length(outHeight),
            vDSP_Length(inputRowBytes / channels),
            vDSP_Length(outWidth)
        )

        let release: CVPixelBufferReleaseBytesCallback = { _, pointer in
            if let pointer {
                free(UnsafeMutableRawPointer(mutating: pointer))
            }
        }

        var cropped: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(
            nil,
            Int(outWidth),
            Int(outHeight),
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            croppedBytes,
            croppedRowBytes,
            release,
            nil,
            nil,
            &cropped
        )
        guard status == kCVReturnSuccess else {
            free(croppedBytes)
            return nil
        }
        return cropped
    }

    static func rotated(_ pixelBuffer: CVPixelBuffer, byDegrees rotationAngle: Int) -> CVPixelBuffer? {
        var rotationConstant = kRotate0DegreesClockwise
        switch rotationAngle {
        case 90:
            rotationConstant = kRotate90DegreesClockwise
        case 180, -180:
            rotationConstant = kRotate180DegreesClockwise
        case 270, -90:
            rotationConstant = kRotate270DegreesClockwise
        default:
            break
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let sourceBuffer = try? vImageBuffer(of: pixelBuffer) else { return nil }

        let bitsPerPixel = CVPixelBufferGetBytesPerRow(pixelBuffer) / CVPixelBufferGetWidth(pixelBuffer) * 8
        guard var destinationBuffer = try? vImage_Buffer(
            width: CVPixelBufferGetHeight(pixelBuffer),
            height: CVPixelBufferGetWidth(pixelBuffer),
            bitsPerPixel: UInt32(bitsPerPixel)
        ) else { return nil }

        let error = withUnsafePointer(to: sourceBuffer) {
            vImageRotate90_ARGB8888($0, &destinationBuffer, UInt8(rotationConstant), [0, 0, 0, 0], vImage_Flags(kvImageNoFlags))
        }
        guard error == kvImageNoError else {
            destinationBuffer.free()
            return nil
        }

        let release: CVPixelBufferReleaseBytesCallback = { _, pointer in
            if let pointer {
                free(UnsafeMutableRawPointer(mutating: pointer))
            }
        }

        var rotated: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(
            nil,
            Int(destinationBuffer.width),
            Int(destinationBuffer.height),
            kCVPixelFormatType_32BGRA,
            destinationBuffer.data,
            destinationBuffer.rowBytes,
            release,
            nil,
            nil,
            &rotated
        )
        guard status == kCVReturnSuccess else {
            destinationBuffer.free()
            return nil
        }
        return rotated
    }

    static func meanAndVariance(of pixelBuffer: CVPixelBuffer) -> (mean: Float, variance: Float) {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
            return (0, 0)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return (0, 0)
        }

        let bgraBuffer = vImage.PixelBuffer(
            data: baseAddress,
            width: width,
            height: height,
            byteCountPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            pixelFormat: vImage.Interleaved8x4.self
        )
        let grayBuffer = vImage.PixelBuffer<vImage.Planar8>(width: width, height: height)

        let divisor = 0x1000
        let scale = Float(divisor)
        let redCoefficient = Float(0.2126)
        let greenCoefficient = Float(0.7152)
        let blueCoefficient = Float(0.0722)

        bgraBuffer.multiply(
            by: (Int(blueCoefficient * scale), Int(greenCoefficient * scale), Int(redCoefficient * scale), 0),
            divisor: divisor,
            preBias: (0, 0, 0, 0),
            postBias: 0,
            destination: grayBuffer
        )

        var laplacianStorage = UnsafeMutableBufferPointer<Float>.allocate(capacity: width * height)
        defer { laplacianStorage.deallocate() }

        let laplacianBuffer = vImage.PixelBuffer(
            data: laplacianStorage.baseAddress!,
            width: width,
            height: height,
            byteCountPerRow: width * MemoryLayout<Float>.stride,
            pixelFormat: vImage.PlanarF.self
        )
        grayBuffer.convert(to: laplacianBuffer)

        var meanLuminance: Float = 0
        vDSP_meanv(laplacianStorage.baseAddress!, 1, &meanLuminance, vDSP_Length(width * height))

        vDSP.convolve(
            laplacianStorage,
            rowCount: height,
            columnCount: width,
            with3x3Kernel: laplacian,
            result: &laplacianStorage
        )

        return (meanLuminance, variance(of: laplacianStorage))
    }

    static func make(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, cgImage.width, cgImage.height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        )
        let bounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        context?.clear(bounds)
        context?.draw(cgImage, in: bounds)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        return pixelBuffer
    }

    static func rotationDegrees(of image: UIImage) -> Int {
        switch image.imageOrientation {
        case .up, .upMirrored:
            0
        case .down, .downMirrored:
            180
        case .left, .leftMirrored:
            -90
        case .right, .rightMirrored:
            90
        @unknown default:
            0
        }
    }

    private static func variance(of buffer: UnsafeMutableBufferPointer<Float>) -> Float {
        var mean = Float.nan
        var standardDeviation = Float.nan
        vDSP_normalize(buffer.baseAddress!, 1, nil, 1, &mean, &standardDeviation, vDSP_Length(buffer.count))
        return standardDeviation * standardDeviation
    }
}

enum IDCImageOps {

    static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(maxSide / longestSide, 1)
        let size = CGSize(width: floor(image.size.width * scale), height: floor(image.size.height * scale))
        let format = image.imageRendererFormat
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func cropped(_ image: UIImage, toPixelRect rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let size = image.size
        var transform: CGAffineTransform
        switch image.imageOrientation {
        case .left:
            transform = CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 0, y: -size.height)
        case .right:
            transform = CGAffineTransform(rotationAngle: -.pi / 2).translatedBy(x: -size.width, y: 0)
        case .down:
            transform = CGAffineTransform(rotationAngle: -.pi).translatedBy(x: -size.width, y: -size.height)
        default:
            transform = .identity
        }
        transform = transform.scaledBy(x: image.scale, y: image.scale)
        guard let cropped = cgImage.cropping(to: rect.applying(transform)) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }

    static func rotated(_ rect: CGRect, byDegrees angle: Int, containerSize: CGSize) -> CGRect {
        switch angle {
        case 90, -270:
            CGRect(x: containerSize.width - rect.maxY, y: rect.minX, width: rect.height, height: rect.width)
        case 270, -90:
            CGRect(x: rect.minY, y: containerSize.height - rect.maxX, width: rect.height, height: rect.width)
        case 180, -180:
            CGRect(x: containerSize.width - rect.maxX, y: containerSize.height - rect.maxY, width: rect.width, height: rect.height)
        default:
            rect
        }
    }

    static func normalized(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: rect.origin.x / size.width, y: rect.origin.y / size.height, width: rect.width / size.width, height: rect.height / size.height)
    }

    static func denormalized(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: rect.origin.x * size.width, y: rect.origin.y * size.height, width: rect.width * size.width, height: rect.height * size.height)
    }
}
