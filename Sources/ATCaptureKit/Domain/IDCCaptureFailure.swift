import Foundation

public struct IDCCaptureFailure: Equatable {
    public enum Check: Equatable {
        case document
        case quality
    }

    public let check: Check
    public let title: String
    public let message: String

    static let invalidPassport = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.invalidDocumentTitle,
        message: IDCStrings.Failure.invalidPassportMessage
    )
    static let invalidPassportBack = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.invalidDocumentTitle,
        message: IDCStrings.Failure.invalidPassportBackMessage
    )
    static let travelDocument = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.invalidDocumentTitle,
        message: IDCStrings.Failure.travelDocMessage
    )
    static let textHardToRead = IDCCaptureFailure(
        check: .quality,
        title: IDCStrings.Failure.textHardToReadTitle,
        message: IDCStrings.Failure.textHardToReadMessage
    )
    static let lightReflection = IDCCaptureFailure(
        check: .quality,
        title: IDCStrings.Failure.lightReflectionTitle,
        message: IDCStrings.Failure.lightReflectionMessage
    )
    static let fingersOnDocument = IDCCaptureFailure(
        check: .quality,
        title: IDCStrings.Failure.fingersTitle,
        message: IDCStrings.Failure.fingersMessage
    )

    static let scannerNotReady = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.checkFailedTitle,
        message: IDCStrings.Failure.scannerNotReadyMessage
    )
    static let notASelfie = IDCCaptureFailure(
        check: .quality,
        title: IDCStrings.Failure.notASelfieTitle,
        message: IDCStrings.Failure.notASelfieMessage
    )
    static let unreadablePhoto = IDCCaptureFailure(
        check: .document,
        title: IDCStrings.Failure.checkFailedTitle,
        message: IDCStrings.Failure.unreadablePhotoMessage
    )

    static func selfieIssue(_ issue: String?) -> IDCCaptureFailure {
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
