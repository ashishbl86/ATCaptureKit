import UIKit

public enum IDCPiece: String, CaseIterable, Hashable {
    case passportFront
    case passportBack
    case selfie

    public var isPassport: Bool { self != .selfie }

    var defaultEyebrow: String? {
        switch self {
        case .passportFront: return IDCStrings.Eyebrow.frontPage
        case .passportBack: return IDCStrings.Eyebrow.backPage
        case .selfie: return nil
        }
    }

    var displayName: String {
        switch self {
        case .passportFront: return IDCStrings.PieceName.frontPage
        case .passportBack: return IDCStrings.PieceName.backPage
        case .selfie: return IDCStrings.PieceName.selfie
        }
    }
}

public enum IDCCaptureSource {
    case liveScan
    case gallery
}

public struct IDCCaptureResult: Identifiable {
    let captureToken: UUID
    public let piece: IDCPiece
    public let image: UIImage
    public let source: IDCCaptureSource
    public let fieldDetections: IDCFieldDetections?

    public var id: String { "\(piece.rawValue)-\(captureToken.uuidString)" }

    init(
        piece: IDCPiece,
        image: UIImage,
        source: IDCCaptureSource,
        fieldDetections: IDCFieldDetections? = nil,
        captureToken: UUID = UUID()
    ) {
        self.captureToken = captureToken
        self.piece = piece
        self.image = image
        self.source = source
        self.fieldDetections = fieldDetections
    }
}

public enum IDCVerificationOutcome {
    case verified(payload: Any?)
    case rejected(reason: String)
    case failed(message: String)

    public static var verified: IDCVerificationOutcome { .verified(payload: nil) }
}
