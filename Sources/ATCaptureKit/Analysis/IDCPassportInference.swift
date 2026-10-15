import CoreGraphics
import CoreVideo
import UIKit

enum IDCPassportDetectionClass: Int, CaseIterable {
    case passportFront = 0
    case passportBack = 1
    case mrz = 2
    case glare = 3
    case finger = 4
    case photoId = 5
    case sign = 6
    case barcode = 7
    case punch = 8
    case travelDoc = 9
    case entryPermit = 10

    var confidenceThreshold: Float32 {
        switch self {
        case .passportFront, .passportBack, .mrz: return 0.7
        case .glare: return 0.3
        case .finger: return 0.5
        case .photoId: return 0.6
        case .sign: return 0.4
        case .barcode: return 0.6
        case .punch: return 0.6
        case .travelDoc: return 0.6
        case .entryPermit: return 0.0
        }
    }
}

struct IDCPassportDetectedBox {
    let detectionClass: IDCPassportDetectionClass
    let confidence: Float32
    let normalizedRect: CGRect
}

extension IDCFieldDetections {
    init(passportRect: CGRect, allBoxes: [IDCPassportDetectedBox]) {
        func best(_ detectionClass: IDCPassportDetectionClass) -> CGRect? {
            guard passportRect.width > 0, passportRect.height > 0,
                  let box = allBoxes.first(where: { $0.detectionClass == detectionClass })?.normalizedRect
            else { return nil }
            let left = min(max((box.minX - passportRect.minX) / passportRect.width, 0), 1)
            let top = min(max((box.minY - passportRect.minY) / passportRect.height, 0), 1)
            let right = min(max((box.maxX - passportRect.minX) / passportRect.width, 0), 1)
            let bottom = min(max((box.maxY - passportRect.minY) / passportRect.height, 0), 1)
            let rebased = CGRect(x: left, y: top, width: right - left, height: bottom - top)
            return (rebased.width >= 0.02 && rebased.height >= 0.02) ? rebased : nil
        }
        self.init(photo: best(.photoId), signature: best(.sign), mrz: best(.mrz))
    }
}

final class IDCPassportInference: @unchecked Sendable {

    private struct Prediction: Comparable {
        let confidenceScore: Float32
        let boundingBox: CGRect

        static func < (lhs: Prediction, rhs: Prediction) -> Bool {
            lhs.confidenceScore < rhs.confidenceScore
        }

        static func == (lhs: Prediction, rhs: Prediction) -> Bool {
            lhs.confidenceScore == rhs.confidenceScore
        }
    }

    private typealias Box = (centerX: Float32, centerY: Float32, width: Float32, height: Float32)

    private static let inputSize = CGSize(width: 640, height: 640)
    private static let glareInputSize = CGSize(width: 256, height: 256)

    private let detector: IDCModelSlot
    private let glare: IDCModelSlot
    private let detectorInput = IDCImageTensorizer(inputSize: inputSize, mean: 127.5, standardDeviation: 127.5)
    private let glareInput = IDCImageTensorizer(
        inputSize: glareInputSize,
        mean: 0,
        standardDeviation: 255,
        channelMeans: (red: 0.485, green: 0.456, blue: 0.406),
        channelDeviations: (red: 0.229, green: 0.224, blue: 0.225)
    )

    init(runner: IDCModelRunner?) {
        detector = IDCModelSlot(.passportDetector, runner: runner)
        glare = IDCModelSlot(.glareClassifier, runner: runner)
    }

    var isReady: Bool {
        detector.isReady && glare.isReady
    }

    func analyze(_ image: UIImage, isForBackPage: Bool, checks: IDCPassportChecks) throws -> IDCPassportAnalysis {
        guard let pixelBuffer = IDCPixelBuffers.make(from: image) else {
            throw IDCAnalysisError.imageConversion
        }
        return try analyze(
            pixelBuffer,
            rotationDegrees: IDCPixelBuffers.rotationDegrees(of: image),
            isForBackPage: isForBackPage,
            checks: checks
        )
    }

    func analyze(_ pixelBuffer: CVPixelBuffer, rotationDegrees: Int, isForBackPage: Bool, checks: IDCPassportChecks) throws -> IDCPassportAnalysis {
        guard isReady else { throw IDCAnalysisError.modelNotReady }

        let output = IDCTensorReader(try detector.run(detectorInput.tensor(from: pixelBuffer, rotationDegrees: rotationDegrees)))
        guard output.isConsistent,
              output.dimensions.count == 3,
              output.dimensions[1] - 4 >= IDCPassportDetectionClass.allCases.count else {
            throw IDCAnalysisError.unexpectedTensor
        }

        let classCount = output.dimensions[1] - 4
        let anchorCount = output.dimensions[2]
        let passportClass: IDCPassportDetectionClass = isForBackPage ? .passportBack : .passportFront

        var fingerPredictions = [Prediction]()
        var travelDocPredictions = [Prediction]()
        var maxConfidencePerClass = [Float32](repeating: 0, count: classCount)
        var boxPerClass = [Box?](repeating: nil, count: classCount)

        let imageRect = Self.fittingRect(
            ratio: Self.aspectRatio(of: pixelBuffer, rotationDegrees: rotationDegrees),
            container: Self.inputSize
        )
        let inputWidth = Float32(Self.inputSize.width)
        let inputHeight = Float32(Self.inputSize.height)

        for index in 0..<anchorCount {
            let box: Box = (
                output[0, 0, index] * inputWidth,
                output[0, 1, index] * inputHeight,
                output[0, 2, index] * inputWidth,
                output[0, 3, index] * inputHeight
            )
            let travelDocConfidence = output[0, 4 + IDCPassportDetectionClass.travelDoc.rawValue, index]
            let fingerConfidence = output[0, 4 + IDCPassportDetectionClass.finger.rawValue, index]

            for classIndex in 0..<classCount {
                let confidence = output[0, 4 + classIndex, index]
                if confidence > maxConfidencePerClass[classIndex] {
                    maxConfidencePerClass[classIndex] = confidence
                    boxPerClass[classIndex] = box
                }
            }

            let normalizedBox = Self.normalizedBox(box, in: imageRect)
            if travelDocConfidence > 0.6 {
                travelDocPredictions.append(Prediction(confidenceScore: travelDocConfidence, boundingBox: normalizedBox))
            }
            if fingerConfidence >= 0.5 {
                fingerPredictions.append(Prediction(confidenceScore: fingerConfidence, boundingBox: normalizedBox))
            }
        }

        let isMRZVisible = maxConfidencePerClass[IDCPassportDetectionClass.mrz.rawValue] >= IDCPassportDetectionClass.mrz.confidenceThreshold

        guard maxConfidencePerClass[passportClass.rawValue] > passportClass.confidenceThreshold else {
            let oppositePage: IDCPassportDetectionClass = isForBackPage ? .passportFront : .passportBack
            return .noPassport(wrongPageInFrame: maxConfidencePerClass[oppositePage.rawValue] > oppositePage.confidenceThreshold)
        }

        let passportBox = boxPerClass[passportClass.rawValue] ?? (0, 0, 0, 0)
        let mrzBox = boxPerClass[IDCPassportDetectionClass.mrz.rawValue] ?? (0, 0, 0, 0)

        let fingers = Self.nonMaximumSuppression(fingerPredictions)
        let travelDocs = Self.nonMaximumSuppression(travelDocPredictions)

        var isTravelDocument = false
        if travelDocs.count == 1 {
            isTravelDocument = travelDocs[0].confidenceScore >= 0.8
        } else if travelDocs.count >= 2 {
            isTravelDocument = true
        }

        let passportRect = Self.normalizedBox(passportBox, in: imageRect)

        var hasFingers = false
        var hasGlare = false

        if isMRZVisible {
            let mrzRect = Self.normalizedBox(mrzBox, in: imageRect)
            let detailsRect = Self.detailsRect(passport: passportRect, mrz: mrzRect, imageSize: imageRect.size)

            if checks.fingers {
                hasFingers = Self.intersects(detailsRect, fingers, imageSize: imageRect.size)
            }

            if checks.glare {
                hasGlare = try glareDetected(
                    in: pixelBuffer,
                    rotationDegrees: rotationDegrees,
                    crop: IDCImageOps.rotated(passportRect, byDegrees: -rotationDegrees, containerSize: CGSize(width: 1, height: 1))
                )
            }
        }

        var allBoxes: [IDCPassportDetectedBox] = []
        for classIndex in 0..<classCount {
            guard let box = boxPerClass[classIndex],
                  let detectionClass = IDCPassportDetectionClass(rawValue: classIndex),
                  maxConfidencePerClass[classIndex] >= detectionClass.confidenceThreshold
            else { continue }
            allBoxes.append(IDCPassportDetectedBox(
                detectionClass: detectionClass,
                confidence: maxConfidencePerClass[classIndex],
                normalizedRect: Self.normalizedBox(box, in: imageRect)
            ))
        }

        return .passport(IDCPassportDetection(
            bounds: passportRect,
            isMRZVisible: isMRZVisible,
            isTravelDocument: isTravelDocument,
            hasFingers: hasFingers,
            hasGlare: hasGlare,
            fieldDetections: IDCFieldDetections(passportRect: passportRect, allBoxes: allBoxes)
        ))
    }

    private func glareDetected(in pixelBuffer: CVPixelBuffer, rotationDegrees: Int, crop: CGRect) throws -> Bool {
        let output = IDCTensorReader(try glare.run(glareInput.tensor(from: pixelBuffer, rotationDegrees: rotationDegrees, normalizedCrop: crop)))
        guard output.isConsistent, output.dimensions.count == 2, output.dimensions[1] >= 2 else {
            throw IDCAnalysisError.unexpectedTensor
        }

        let probabilities = Self.softmax([output[0, 0], output[0, 1]])
        let glareProbability = probabilities[0]
        let clearProbability = probabilities[1]
        let confidence = max(glareProbability, clearProbability)
        return glareProbability > clearProbability && confidence > 0.8
    }

    private static func softmax(_ values: [Float]) -> [Float] {
        let maxValue = values.max() ?? 0
        let exponentials = values.map { expf($0 - maxValue) }
        let sum = exponentials.reduce(0, +)
        return exponentials.map { $0 / sum }
    }

    private static func aspectRatio(of pixelBuffer: CVPixelBuffer, rotationDegrees: Int) -> Double {
        let ratio = Double(CVPixelBufferGetWidth(pixelBuffer)) / Double(CVPixelBufferGetHeight(pixelBuffer))
        if abs(rotationDegrees) == 90 || abs(rotationDegrees) == 270 {
            return 1.0 / ratio
        }
        return ratio
    }

    private static func fittingRect(ratio: Double, container: CGSize) -> CGRect {
        let ratio = CGFloat(ratio)
        if ratio <= container.width / container.height {
            let height = container.height
            let width = height * ratio
            return CGRect(x: (container.width - width) / 2, y: 0, width: width, height: height)
        }
        let width = container.width
        let height = width / ratio
        return CGRect(x: 0, y: (container.height - height) / 2, width: width, height: height)
    }

    private static func normalizedBox(_ box: Box, in imageRect: CGRect) -> CGRect {
        let rect = CGRect(
            x: CGFloat(box.centerX - box.width / 2) - imageRect.origin.x,
            y: CGFloat(box.centerY - box.height / 2) - imageRect.origin.y,
            width: CGFloat(box.width),
            height: CGFloat(box.height)
        )
        return CGRect(
            x: rect.origin.x / imageRect.width,
            y: rect.origin.y / imageRect.height,
            width: rect.width / imageRect.width,
            height: rect.height / imageRect.height
        )
    }

    private static func detailsRect(passport: CGRect, mrz: CGRect, imageSize: CGSize) -> CGRect {
        let passportRect = IDCImageOps.denormalized(passport, in: imageSize)
        let mrzRect = IDCImageOps.denormalized(mrz, in: imageSize)

        let originY = passportRect.origin.y + mrzRect.height * 0.1
        let bottomY = mrzRect.origin.y + mrzRect.height - mrzRect.height * 0.1
        let originX = mrzRect.origin.x + mrzRect.width * 0.03
        let endX = mrzRect.origin.x + mrzRect.width - mrzRect.width * 0.02

        return CGRect(x: originX, y: originY, width: endX - originX, height: bottomY - originY)
    }

    private static func intersects(_ rect: CGRect, _ detections: [Prediction], imageSize: CGSize) -> Bool {
        detections.contains { detection in
            IDCImageOps.denormalized(detection.boundingBox, in: imageSize).intersects(rect)
        }
    }

    private static func nonMaximumSuppression(_ predictions: [Prediction]) -> [Prediction] {
        var remaining = predictions.sorted(by: >)
        var kept = [Prediction]()

        while !remaining.isEmpty {
            let best = remaining.removeFirst()
            kept.append(best)
            remaining = remaining.filter { intersectionOverUnion(best.boundingBox, $0.boundingBox) < 0.5 }
        }

        return kept
    }

    private static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> Float {
        let areaA = a.width * a.height
        if areaA <= 0 { return 0 }

        let areaB = b.width * b.height
        if areaB <= 0 { return 0 }

        let intersectionMinX = max(a.minX, b.minX)
        let intersectionMinY = max(a.minY, b.minY)
        let intersectionMaxX = min(a.maxX, b.maxX)
        let intersectionMaxY = min(a.maxY, b.maxY)
        let intersectionArea = max(intersectionMaxY - intersectionMinY, 0) * max(intersectionMaxX - intersectionMinX, 0)
        return Float(intersectionArea / (areaA + areaB - intersectionArea))
    }
}
