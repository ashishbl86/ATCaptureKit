import CoreMotion
import UIKit
import Vision

enum IDCSelfieImage {
    case liveFrame(CVPixelBuffer, isFrontCamera: Bool, viewfinderBounds: CGRect)
    case upload(UIImage)
}

struct IDCSelfieInspection {
    let messages: [IDCSelfieGuidance]
    let variance: Float
    let faceRects: [CGRect]
}

final class IDCSelfieInference: @unchecked Sendable {

    private static let inputSize = CGSize(width: 256, height: 256)
    private static let faceRatioEnterMin: CGFloat = 0.22
    private static let faceRatioEnterMax: CGFloat = 0.30
    private static let faceRatioExitMin: CGFloat = 0.20
    private static let faceRatioExitMax: CGFloat = 0.33
    private static let faceCenterEnterFactor: CGFloat = 0.15
    private static let faceCenterExitFactor: CGFloat = 0.22
    private static let maxStraightPitchDegrees: CGFloat = 10
    private static let maxStraightYawDegrees: CGFloat = 10
    private static let maxStraightRollDegrees: CGFloat = 10
    private static let maxPhonePitchGravityY: Double = -0.940
    private static let maxPhoneRollGravityX: Double = 0.259
    private static let uploadMinFaceSpanRatio: CGFloat = 0.25
    private static let maxEmbeddedFaceSpanRatio: CGFloat = 0.45
    private static let minSurroundingTextRegions = 4
    private static let minSurroundingTextConfidence: Float = 0.4
    private static let uploadMaxSide: CGFloat = 1000

    private let classifier: IDCModelSlot
    private let classifierInput = IDCImageTensorizer(inputSize: inputSize, mean: 0, standardDeviation: 255)
    private let liveChecks: IDCSelfieChecks
    private let uploadChecks: IDCSelfieChecks
    private var faceFitLatched = false

    init(runner: IDCModelRunner?, liveChecks: IDCSelfieChecks, uploadChecks: IDCSelfieChecks) {
        classifier = IDCModelSlot(.selfieClassifier, runner: runner)
        self.liveChecks = liveChecks
        self.uploadChecks = uploadChecks
    }

    var isReady: Bool {
        classifier.isReady
    }

    func inspect(_ image: IDCSelfieImage, deviceMotion: CMDeviceMotion?) -> IDCSelfieInspection {
        let (brightness, variance) = meanAndVariance(of: image) ?? (100, 100)

        guard isReady else {
            return IDCSelfieInspection(messages: [.autoCapturing], variance: variance, faceRects: [])
        }

        if brightness < 0.3 {
            return IDCSelfieInspection(messages: [.tooDark], variance: variance, faceRects: [])
        }

        do {
            var messages = [IDCSelfieGuidance]()
            var faceRects = [CGRect]()

            switch image {
            case .liveFrame(let pixelBuffer, let isFrontCamera, let viewfinderBounds):
                let checks = liveChecks
                let bufferSize = IDCPixelBuffers.size(of: pixelBuffer)
                let orientedSize = CGSize(width: bufferSize.height, height: bufferSize.width)
                let orientation: CGImagePropertyOrientation = isFrontCamera ? .leftMirrored : .right
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
                let faces = try detectFaces(handler: handler)

                guard let primaryObservation = faces.first else {
                    faceFitLatched = false
                    return IDCSelfieInspection(messages: [.faceMissing], variance: variance, faceRects: [])
                }

                if faces.count > 1 {
                    faceFitLatched = false
                    return IDCSelfieInspection(messages: [.multipleFaces], variance: variance, faceRects: [])
                }

                let face = IDCDetectedFace(observation: primaryObservation, orientedSize: orientedSize)

                guard let rotatedPixelBuffer = IDCPixelBuffers.rotated(pixelBuffer, byDegrees: 90) else {
                    return IDCSelfieInspection(messages: [.autoCapturing], variance: variance, faceRects: faceRects)
                }
                let rotatedSize = IDCPixelBuffers.size(of: rotatedPixelBuffer)

                faceRects.append(IDCImageOps.normalized(face.frame, in: rotatedSize))

                if let deviceMotion {
                    if deviceMotion.gravity.y > Self.maxPhonePitchGravityY {
                        faceFitLatched = false
                        return IDCSelfieInspection(messages: [.holdStraight], variance: variance, faceRects: faceRects)
                    }

                    if abs(deviceMotion.gravity.x) > Self.maxPhoneRollGravityX {
                        faceFitLatched = false
                        return IDCSelfieInspection(messages: [.tilted], variance: variance, faceRects: faceRects)
                    }
                }

                let faceRect = face.frame
                let faceInViewfinder = faceRectInViewfinder(viewfinderBounds, faceRect: faceRect, frameSize: rotatedSize)
                let faceRatio = (faceInViewfinder.width * faceInViewfinder.height) / (viewfinderBounds.width * viewfinderBounds.height)

                if !viewfinderBounds.contains(faceInViewfinder) {
                    faceFitLatched = false
                    return IDCSelfieInspection(messages: [.faceOutOfBounds], variance: variance, faceRects: faceRects)
                }

                if let message = classify(isFrontCamera: isFrontCamera, faceRect: faceRect, frame: rotatedPixelBuffer) {
                    return IDCSelfieInspection(messages: [message], variance: variance, faceRects: faceRects)
                }

                let closeMax = faceFitLatched ? Self.faceRatioExitMax : Self.faceRatioEnterMax
                let farMin = faceFitLatched ? Self.faceRatioExitMin : Self.faceRatioEnterMin
                let centerFactor = faceFitLatched ? Self.faceCenterExitFactor : Self.faceCenterEnterFactor

                if checks.tooClose, faceRatio > closeMax {
                    faceFitLatched = false
                    return IDCSelfieInspection(messages: [.faceTooClose], variance: variance, faceRects: faceRects)
                }

                if faceRatio < farMin {
                    faceFitLatched = false
                    return IDCSelfieInspection(messages: [.faceTooFar], variance: variance, faceRects: faceRects)
                }

                if checks.faceInCenter {
                    let centerX = viewfinderBounds.width / 2
                    let threshold = faceInViewfinder.width * centerFactor
                    let faceCenterX = faceInViewfinder.origin.x + faceInViewfinder.width / 2

                    if faceCenterX < centerX - threshold || faceCenterX > centerX + threshold {
                        faceFitLatched = false
                        return IDCSelfieInspection(messages: [.faceNotCentered], variance: variance, faceRects: faceRects)
                    }
                }

                faceFitLatched = true
                appendFaceChecks(for: face, checks: checks, to: &messages)

            case .upload(let originalImage):
                let checks = uploadChecks
                var visionImage = originalImage
                if let resizedData = IDCImageOps.resized(originalImage, maxSide: Self.uploadMaxSide).pngData(),
                   let resizedImage = UIImage(data: resizedData) {
                    visionImage = resizedImage
                }

                guard let cgImage = visionImage.cgImage else {
                    return IDCSelfieInspection(messages: [.autoCapturing], variance: variance, faceRects: [])
                }

                let orientation = IDCImageOps.orientation(of: visionImage)
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                let faces = try detectFaces(handler: handler)

                guard let primaryObservation = faces.first else {
                    return IDCSelfieInspection(messages: [.faceMissing], variance: variance, faceRects: [])
                }

                if faces.count > 1 {
                    let rects = faces.map {
                        IDCImageOps.normalized(IDCDetectedFace.frame(for: $0, orientedSize: visionImage.size), in: visionImage.size)
                    }
                    return IDCSelfieInspection(messages: [.multipleFaces], variance: variance, faceRects: rects)
                }

                let face = IDCDetectedFace(observation: primaryObservation, orientedSize: visionImage.size)

                faceRects.append(IDCImageOps.normalized(face.frame, in: visionImage.size))

                let faceSpan = max(face.frame.width, face.frame.height)
                let imageShortSide = min(visionImage.size.width, visionImage.size.height)
                let faceSpanRatio = imageShortSide > 0 ? faceSpan / imageShortSide : 1
                if faceSpanRatio < Self.uploadMinFaceSpanRatio {
                    return IDCSelfieInspection(messages: [.notASelfie], variance: variance, faceRects: faceRects)
                }

                if faceSpanRatio < Self.maxEmbeddedFaceSpanRatio,
                   surroundingTextRegionCount(handler: handler, faceBoundingBox: primaryObservation.boundingBox) >= Self.minSurroundingTextRegions {
                    return IDCSelfieInspection(messages: [.notASelfie], variance: variance, faceRects: faceRects)
                }

                let (_, idealCropAvailable) = expandEqually(face.frame, by: 0.4, in: visionImage.size)
                let (cropRect, _) = expandEqually(face.frame, by: 0.6, in: visionImage.size)
                let croppedFace = IDCImageOps.cropped(visionImage, toPixelRect: cropRect) ?? visionImage

                if !idealCropAvailable, checks.tooClose {
                    messages.append(.faceTooClose)
                }

                let classification = classify(croppedFace)

                if checks.glasses, classification.isEyeCovered {
                    messages.append(.specs)
                }

                if checks.coveredFace, classification.isFaceCovered {
                    messages.append(.faceCovered)
                }

                appendFaceChecks(for: face, checks: checks, to: &messages)
            }

            return IDCSelfieInspection(messages: messages.isEmpty ? [.goodPhoto] : messages, variance: variance, faceRects: faceRects)
        } catch {
            return IDCSelfieInspection(messages: [.autoCapturing], variance: variance, faceRects: [])
        }
    }

    private func appendFaceChecks(for face: IDCDetectedFace, checks: IDCSelfieChecks, to messages: inout [IDCSelfieGuidance]) {
        if checks.smile, face.areTeethVisible {
            messages.append(.noTeeth)
        }

        if checks.closedEyes {
            let leftClosed = face.leftEyeOpenProbability < 0.8
            let rightClosed = face.rightEyeOpenProbability < 0.8
            if leftClosed && rightClosed {
                messages.append(.bothEyesClosed)
            } else if leftClosed || rightClosed {
                messages.append(.oneEyeClosed)
            }
        }

        if checks.faceStraight {
            if face.headEulerAngleX < -Self.maxStraightPitchDegrees {
                messages.append(.faceDown)
            }

            if face.headEulerAngleX > Self.maxStraightPitchDegrees {
                messages.append(.faceUp)
            }

            if face.headEulerAngleY < -Self.maxStraightYawDegrees || face.headEulerAngleZ > Self.maxStraightRollDegrees {
                messages.append(.faceLeft)
            }

            if face.headEulerAngleY > Self.maxStraightYawDegrees || face.headEulerAngleZ < -Self.maxStraightRollDegrees {
                messages.append(.faceRight)
            }
        }
    }

    private func meanAndVariance(of image: IDCSelfieImage) -> (Float, Float)? {
        switch image {
        case .liveFrame(let pixelBuffer, _, _):
            let measured = IDCPixelBuffers.meanAndVariance(of: pixelBuffer)
            return (measured.mean, measured.variance)
        case .upload(let image):
            guard let pixelBuffer = IDCPixelBuffers.make(from: image) else { return nil }
            let measured = IDCPixelBuffers.meanAndVariance(of: pixelBuffer)
            return (measured.mean, measured.variance)
        }
    }

    private func detectFaces(handler: VNImageRequestHandler) throws -> [VNFaceObservation] {
        let request = VNDetectFaceLandmarksRequest()
        try handler.perform([request])
        return request.results ?? []
    }

    private func surroundingTextRegionCount(handler: VNImageRequestHandler, faceBoundingBox: CGRect) -> Int {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        guard (try? handler.perform([request])) != nil else { return 0 }

        return (request.results ?? []).filter { observation in
            guard !observation.boundingBox.intersects(faceBoundingBox),
                  let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= Self.minSurroundingTextConfidence
            else { return false }
            return candidate.string.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        }.count
    }

    private func faceRectInViewfinder(_ viewfinderBounds: CGRect, faceRect: CGRect, frameSize containerSize: CGSize) -> CGRect {
        let viewfinderAspectRatio = viewfinderBounds.width / viewfinderBounds.height

        if viewfinderAspectRatio <= containerSize.width / containerSize.height {
            let boxHeight = containerSize.height
            let boxWidth = boxHeight * viewfinderAspectRatio
            let scale = viewfinderBounds.height / boxHeight
            let xOffset = (containerSize.width - boxWidth) / 2
            let rect = CGRect(origin: CGPoint(x: faceRect.origin.x - xOffset, y: faceRect.origin.y), size: faceRect.size)
            return rect.applying(CGAffineTransform(scaleX: scale, y: scale))
        }

        let boxWidth = containerSize.width
        let boxHeight = boxWidth / viewfinderAspectRatio
        let scale = viewfinderBounds.width / boxWidth
        let yOffset = (containerSize.height - boxHeight) / 2
        let rect = CGRect(origin: CGPoint(x: faceRect.origin.x, y: faceRect.origin.y - yOffset), size: faceRect.size)
        return rect.applying(CGAffineTransform(scaleX: scale, y: scale))
    }

    private func expandEqually(_ rect: CGRect, by scalingFactor: CGFloat, in containerSize: CGSize) -> (CGRect, Bool) {
        var expandSuccessful = true

        let topSpaceToAdd = rect.height * scalingFactor
        let topSpaceAvailable = rect.origin.y
        if topSpaceToAdd > topSpaceAvailable {
            expandSuccessful = false
        }

        let bottomSpaceToAdd = rect.height * scalingFactor
        let bottomSpaceAvailable = containerSize.height - rect.origin.y - rect.height
        if bottomSpaceToAdd > bottomSpaceAvailable {
            expandSuccessful = false
        }

        let leadingSpaceToAdd = rect.width * scalingFactor
        let leadingSpaceAvailable = rect.origin.x
        if leadingSpaceToAdd > leadingSpaceAvailable {
            expandSuccessful = false
        }

        let trailingSpaceToAdd = rect.width * scalingFactor
        let trailingSpaceAvailable = containerSize.width - rect.origin.x - rect.width
        if trailingSpaceToAdd > trailingSpaceAvailable {
            expandSuccessful = false
        }

        let spaceToAddAround = min(
            min(leadingSpaceToAdd, leadingSpaceAvailable),
            min(topSpaceToAdd, topSpaceAvailable),
            min(bottomSpaceToAdd, bottomSpaceAvailable),
            min(trailingSpaceToAdd, trailingSpaceAvailable)
        )

        let cropRect = CGRect(
            x: rect.origin.x - spaceToAddAround,
            y: rect.origin.y - spaceToAddAround,
            width: rect.width + spaceToAddAround * 2,
            height: rect.height + spaceToAddAround * 2
        )

        return (cropRect, expandSuccessful)
    }

    private func classify(isFrontCamera: Bool, faceRect: CGRect, frame: CVPixelBuffer) -> IDCSelfieGuidance? {
        let frameSize = IDCPixelBuffers.size(of: frame)
        let faceInFrame: CGRect
        if isFrontCamera {
            faceInFrame = CGRect(
                origin: CGPoint(x: frameSize.width - faceRect.origin.x - faceRect.width, y: faceRect.origin.y),
                size: faceRect.size
            )
        } else {
            faceInFrame = faceRect
        }

        let (cropRect, _) = expandEqually(faceInFrame, by: 0.4, in: frameSize)
        let faceBuffer = IDCPixelBuffers.crop(frame, to: cropRect) ?? frame
        let classification = classify(faceBuffer, rotationDegrees: 0)

        if classification.isEyeCovered {
            return .specs
        } else if classification.isFaceCovered {
            return .faceCovered
        }
        return nil
    }

    private func classify(_ image: UIImage) -> (isEyeCovered: Bool, isFaceCovered: Bool) {
        guard let pixelBuffer = IDCPixelBuffers.make(from: image) else { return (false, false) }
        return classify(pixelBuffer, rotationDegrees: IDCPixelBuffers.rotationDegrees(of: image))
    }

    private func classify(_ pixelBuffer: CVPixelBuffer, rotationDegrees: Int) -> (isEyeCovered: Bool, isFaceCovered: Bool) {
        guard isReady,
              let tensor = try? classifier.run(classifierInput.tensor(from: pixelBuffer, rotationDegrees: rotationDegrees)) else {
            return (false, false)
        }

        let output = IDCTensorReader(tensor)
        guard output.isConsistent, output.dimensions.count == 2, output.dimensions[1] >= 4 else {
            return (false, false)
        }

        let eyeConfidence = output[0, 0]
        let faceCoveredConfidence = output[0, 1]
        let headCoveredConfidence = output[0, 2]
        let allGoodConfidence = output[0, 3]
        let maxConfidence = max(eyeConfidence, faceCoveredConfidence, headCoveredConfidence, allGoodConfidence)

        if eyeConfidence == maxConfidence {
            return (true, false)
        } else if faceCoveredConfidence == maxConfidence {
            return (false, true)
        }
        return (false, false)
    }
}

private struct IDCDetectedFace {
    let frame: CGRect
    let headEulerAngleX: CGFloat
    let headEulerAngleY: CGFloat
    let headEulerAngleZ: CGFloat
    let leftEyeOpenProbability: CGFloat
    let rightEyeOpenProbability: CGFloat
    let areTeethVisible: Bool

    private static let eyeClosedRatio: CGFloat = 0.12
    private static let eyeOpenRatio: CGFloat = 0.23
    private static let teethOpenRatioThreshold: CGFloat = 0.10

    init(observation: VNFaceObservation, orientedSize: CGSize) {
        frame = Self.frame(for: observation, orientedSize: orientedSize)
        headEulerAngleX = Self.normalizedDegrees(observation.pitch?.doubleValue ?? 0)
        headEulerAngleY = Self.normalizedDegrees(observation.yaw?.doubleValue ?? 0)
        headEulerAngleZ = Self.normalizedDegrees(observation.roll?.doubleValue ?? 0)

        let landmarks = observation.landmarks
        leftEyeOpenProbability = Self.eyeOpenProbability(landmarks?.leftEye, imageSize: orientedSize)
        rightEyeOpenProbability = Self.eyeOpenProbability(landmarks?.rightEye, imageSize: orientedSize)
        areTeethVisible = Self.teethVisible(landmarks: landmarks, imageSize: orientedSize)
    }

    static func frame(for observation: VNFaceObservation, orientedSize: CGSize) -> CGRect {
        let bottomLeftBox = VNImageRectForNormalizedRect(
            observation.boundingBox,
            Int(orientedSize.width.rounded()),
            Int(orientedSize.height.rounded())
        )
        return CGRect(
            x: bottomLeftBox.minX,
            y: orientedSize.height - bottomLeftBox.maxY,
            width: bottomLeftBox.width,
            height: bottomLeftBox.height
        )
    }

    private static func teethVisible(landmarks: VNFaceLandmarks2D?, imageSize: CGSize) -> Bool {
        guard let inner = landmarks?.innerLips?.pointsInImage(imageSize: imageSize), inner.count >= 3 else {
            return false
        }

        let innerYs = inner.map { $0.y }
        let innerXs = inner.map { $0.x }
        guard let minY = innerYs.min(), let maxY = innerYs.max(),
              let minX = innerXs.min(), let maxX = innerXs.max() else {
            return false
        }

        let verticalOpening = maxY - minY
        let mouthWidth: CGFloat
        if let outer = landmarks?.outerLips?.pointsInImage(imageSize: imageSize), !outer.isEmpty {
            let outerXs = outer.map { $0.x }
            mouthWidth = (outerXs.max() ?? maxX) - (outerXs.min() ?? minX)
        } else {
            mouthWidth = maxX - minX
        }

        guard mouthWidth > 0 else { return false }
        return verticalOpening / mouthWidth > teethOpenRatioThreshold
    }

    private static func eyeOpenProbability(_ eye: VNFaceLandmarkRegion2D?, imageSize: CGSize) -> CGFloat {
        guard let points = eye?.pointsInImage(imageSize: imageSize), points.count >= 4 else {
            return 1.0
        }

        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(),
              let minY = ys.min(), let maxY = ys.max() else {
            return 1.0
        }

        let width = maxX - minX
        guard width > 0 else { return 1.0 }

        let ratio = (maxY - minY) / width
        return min(max((ratio - eyeClosedRatio) / (eyeOpenRatio - eyeClosedRatio), 0), 1)
    }

    private static func normalizedDegrees(_ radians: Double) -> CGFloat {
        var degrees = radians * 180.0 / .pi
        while degrees > 180 { degrees -= 360 }
        while degrees < -180 { degrees += 360 }
        return CGFloat(degrees)
    }
}
