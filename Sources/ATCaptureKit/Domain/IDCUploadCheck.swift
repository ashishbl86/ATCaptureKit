import UIKit

enum IDCUploadCheck {

    enum PassportVerdict {
        case accepted(UIImage, IDCFieldDetections?)
        case rejected(IDCCaptureFailure)
    }

    static func passport(_ analysis: IDCPassportAnalysis?, image: UIImage, isForBackPage: Bool) -> PassportVerdict {
        guard let analysis else { return .rejected(.scannerNotReady) }
        switch analysis {
        case .failed:
            return .rejected(.unreadablePhoto)
        case .noPassport:
            return .rejected(isForBackPage ? .invalidPassportBack : .invalidPassport)
        case .passport(let detection):
            if detection.isTravelDocument {
                return .rejected(.travelDocument)
            } else if !isForBackPage && !detection.isMRZVisible {
                return .rejected(.textHardToRead)
            } else if detection.hasFingers {
                return .rejected(.fingersOnDocument)
            } else if detection.hasGlare {
                return .rejected(.lightReflection)
            }
            return .accepted(crop(image, toNormalizedRect: detection.bounds) ?? image, detection.fieldDetections)
        }
    }

    static func selfie(_ analysis: IDCSelfiePhotoAnalysis?) -> IDCCaptureFailure? {
        switch analysis {
        case nil:
            return .scannerNotReady
        case .document:
            return .notASelfie
        case .analyzed(.goodPhoto):
            return nil
        case .analyzed(.autoCapturing):
            return .selfieIssue(nil)
        case .analyzed(let guidance):
            return .selfieIssue(guidance.rawValue)
        }
    }

    static func crop(_ image: UIImage, toNormalizedRect rect: CGRect) -> UIImage? {
        guard image.cgImage != nil,
              rect.minX >= 0, rect.minY >= 0, rect.maxX <= 1, rect.maxY <= 1,
              rect.width > 0.1, rect.height > 0.1 else { return nil }
        return IDCImageOps.cropped(image, toPixelRect: IDCImageOps.denormalized(rect, in: image.size))
    }
}
