import Accelerate
import CoreGraphics
import CoreVideo
import Foundation

struct IDCImageTensorizer {
    let inputSize: CGSize
    let mean: Float
    let standardDeviation: Float
    var channelMeans: (red: Float, green: Float, blue: Float)?
    var channelDeviations: (red: Float, green: Float, blue: Float)?

    func tensor(from pixelBuffer: CVPixelBuffer, rotationDegrees: Int, normalizedCrop: CGRect? = nil) throws -> Data {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
            throw IDCAnalysisError.imageConversion
        }

        let input = croppedBuffer(pixelBuffer, normalizedCrop: normalizedCrop)

        CVPixelBufferLockBaseAddress(input, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(input, .readOnly) }

        let source = try IDCPixelBuffers.vImageBuffer(of: input)

        var scaled = try vImage_Buffer(size: inputSize, bitsPerPixel: 32)
        defer { scaled.free() }

        guard rotateAndScale(source: source, destination: &scaled, byAngleInDegrees: Double(rotationDegrees)) == kvImageNoError else {
            throw IDCAnalysisError.imageConversion
        }

        var rgb = try vImage_Buffer(size: inputSize, bitsPerPixel: 24)
        defer { rgb.free() }

        guard vImageConvert_BGRA8888toRGB888(&scaled, &rgb, UInt32(kvImageNoFlags)) == kvImageNoError else {
            throw IDCAnalysisError.imageConversion
        }

        let floats = floatBuffer(from: rgb, bytesPerPixel: 3)
        let normalized = normalize(floats)
        let meanAdjusted = adjustChannelMeans(normalized)
        let deviationAdjusted = adjustChannelDeviations(meanAdjusted)
        return deviationAdjusted.withUnsafeBufferPointer(Data.init)
    }

    private func croppedBuffer(_ pixelBuffer: CVPixelBuffer, normalizedCrop: CGRect?) -> CVPixelBuffer {
        guard let normalizedCrop,
              let cropped = IDCPixelBuffers.crop(
                  pixelBuffer,
                  to: IDCImageOps.denormalized(normalizedCrop, in: IDCPixelBuffers.size(of: pixelBuffer))
              ) else { return pixelBuffer }
        return cropped
    }

    private func floatBuffer(from imageBuffer: vImage_Buffer, bytesPerPixel: Int) -> [Float32] {
        let count = Int(imageBuffer.height) * imageBuffer.rowBytes
        let floats = [Float32](unsafeUninitializedCapacity: count) { buffer, initializedCount in
            vDSP_vfltu8(imageBuffer.data.assumingMemoryBound(to: UInt8.self), 1, buffer.baseAddress!, 1, UInt(count))
            initializedCount = count
        }

        if imageBuffer.rowBytes == Int(inputSize.width) * bytesPerPixel {
            return floats
        }

        let unpaddedCount = Int(inputSize.height * inputSize.width) * bytesPerPixel
        return [Float32](unsafeUninitializedCapacity: unpaddedCount) { buffer, initializedCount in
            let rowCount = UInt(inputSize.height)
            let columnCount = UInt(inputSize.width) * UInt(bytesPerPixel)
            vDSP_mmov(floats, buffer.baseAddress!, columnCount, rowCount, UInt(imageBuffer.rowBytes), columnCount)
            initializedCount = unpaddedCount
        }
    }

    private func normalize(_ floats: [Float32]) -> [Float32] {
        let centered: [Float32]
        if mean == 0 {
            centered = floats
        } else {
            centered = [Float32](unsafeUninitializedCapacity: floats.count) { buffer, initializedCount in
                vDSP_vsadd(floats, 1, [-mean], buffer.baseAddress!, 1, UInt(floats.count))
                initializedCount = floats.count
            }
        }

        return [Float](unsafeUninitializedCapacity: centered.count) { buffer, initializedCount in
            vDSP_vsmul(centered, 1, [1 / standardDeviation], buffer.baseAddress!, 1, UInt(centered.count))
            initializedCount = centered.count
        }
    }

    private func adjustChannelMeans(_ floats: [Float32]) -> [Float32] {
        guard let channelMeans else { return floats }
        let red = add(-channelMeans.red, to: floats, offset: 0)
        let green = add(-channelMeans.green, to: red, offset: 1)
        return add(-channelMeans.blue, to: green, offset: 2)
    }

    private func adjustChannelDeviations(_ floats: [Float32]) -> [Float32] {
        guard let channelDeviations else { return floats }
        let red = multiply(1 / channelDeviations.red, floats, offset: 0)
        let green = multiply(1 / channelDeviations.green, red, offset: 1)
        return multiply(1 / channelDeviations.blue, green, offset: 2)
    }

    private func add(_ scalar: Float32, to floats: [Float32], offset: Int) -> [Float32] {
        var output = floats
        output.withUnsafeMutableBufferPointer { destination in
            floats.withUnsafeBufferPointer { source in
                guard let sourceBase = source.baseAddress, let destinationBase = destination.baseAddress else { return }
                vDSP_vsadd(sourceBase.advanced(by: offset), 3, [scalar], destinationBase.advanced(by: offset), 3, UInt(floats.count / 3))
            }
        }
        return output
    }

    private func multiply(_ scalar: Float32, _ floats: [Float32], offset: Int) -> [Float32] {
        var output = floats
        output.withUnsafeMutableBufferPointer { destination in
            floats.withUnsafeBufferPointer { source in
                guard let sourceBase = source.baseAddress, let destinationBase = destination.baseAddress else { return }
                vDSP_vsmul(sourceBase.advanced(by: offset), 3, [scalar], destinationBase.advanced(by: offset), 3, UInt(floats.count / 3))
            }
        }
        return output
    }

    private func rotateAndScale(
        source: vImage_Buffer,
        destination: inout vImage_Buffer,
        byAngleInDegrees angleInDegrees: Double,
        backgroundColor: [Pixel_8] = [0, 0, 0, 127]
    ) -> vImage_Error {
        let angle = Measurement(value: angleInDegrees * -1, unit: UnitAngle.degrees)
        let radians = CGFloat(angle.converted(to: .radians).value)

        let rotatedBoundingBox = CGRect(origin: .zero, size: source.size)
            .applying(CGAffineTransform(rotationAngle: radians))
        let scale = min(
            destination.size.width / rotatedBoundingBox.size.width,
            destination.size.height / rotatedBoundingBox.size.height
        )

        let cgTransform = CGAffineTransform.identity
            .translatedBy(x: destination.size.width / 2, y: destination.size.height / 2)
            .rotated(by: radians)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -source.size.width / 2, y: -source.size.height / 2)

        var vImageTransform = vImage_CGAffineTransform(
            a: Double(cgTransform.a),
            b: Double(cgTransform.b),
            c: Double(cgTransform.c),
            d: Double(cgTransform.d),
            tx: Double(cgTransform.tx),
            ty: Double(cgTransform.ty)
        )

        return withUnsafePointer(to: source) { sourcePointer in
            vImageAffineWarpCG_ARGB8888(
                sourcePointer,
                &destination,
                nil,
                &vImageTransform,
                backgroundColor,
                vImage_Flags(kvImageBackgroundColorFill)
            )
        }
    }
}

struct IDCTensorReader {
    let dimensions: [Int]
    private let values: [Float32]

    init(_ tensor: IDCTensor) {
        dimensions = tensor.shape
        var values = [Float32](repeating: 0, count: tensor.data.count / MemoryLayout<Float32>.stride)
        _ = values.withUnsafeMutableBytes { tensor.data.copyBytes(to: $0) }
        self.values = values
    }

    var count: Int { values.count }

    var isConsistent: Bool {
        !dimensions.isEmpty && dimensions.reduce(1, *) == values.count
    }

    subscript(_ index: Int...) -> Float32 {
        var flatIndex = 0
        for axis in 0..<dimensions.count {
            flatIndex = dimensions[axis] * flatIndex + index[axis]
        }
        return values[flatIndex]
    }
}
