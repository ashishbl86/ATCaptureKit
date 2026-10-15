import Foundation

public struct IDCCaptureFailure: Equatable {
    public enum Check: Equatable {
        case document
        case quality
    }

    public let check: Check
    public let title: String
    public let message: String

    public static let invalidPassport = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.invalidDocumentTitle,
        message: IDCStrings.Failure.invalidPassportMessage
    )
    public static let invalidPassportBack = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.invalidDocumentTitle,
        message: IDCStrings.Failure.invalidPassportBackMessage
    )
    public static let travelDocument = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.invalidDocumentTitle,
        message: IDCStrings.Failure.travelDocMessage
    )
    public static let textHardToRead = IDCCaptureFailure(
        check: .quality,
        title: IDCStrings.Failure.textHardToReadTitle,
        message: IDCStrings.Failure.textHardToReadMessage
    )
    public static let lightReflection = IDCCaptureFailure(
        check: .quality,
        title: IDCStrings.Failure.lightReflectionTitle,
        message: IDCStrings.Failure.lightReflectionMessage
    )
    public static let fingersOnDocument = IDCCaptureFailure(
        check: .quality,
        title: IDCStrings.Failure.fingersTitle,
        message: IDCStrings.Failure.fingersMessage
    )

    public static let scannerNotReady = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.checkFailedTitle,
        message: IDCStrings.Failure.scannerNotReadyMessage
    )
    public static let notASelfie = IDCCaptureFailure(
        check: .quality,
        title: IDCStrings.Failure.notASelfieTitle,
        message: IDCStrings.Failure.notASelfieMessage
    )
    public static let unreadablePhoto = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.checkFailedTitle,
        message: IDCStrings.Failure.unreadablePhotoMessage
    )

    public static func selfieIssue(_ issue: String?) -> IDCCaptureFailure {
        IDCCaptureFailure(
            check: .quality,
            title: issue ?? IDCStrings.Failure.selfieCheckTitle,
            message: IDCStrings.Failure.selfieCheckMessage
        )
    }

    static func rejection(for piece: IDCPiece, reason: String) -> IDCCaptureFailure {
        IDCCaptureFailure(
            check: .document,
            title: piece.isPassport ? IDCStrings.Failure.invalidDocumentTitle : IDCStrings.Failure.visaPhotoChecksFailed,
            message: reason
        )
    }
}
