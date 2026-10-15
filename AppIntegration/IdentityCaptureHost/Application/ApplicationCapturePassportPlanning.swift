import ATCaptureKit
import Foundation

enum ApplicationCapturePassportPlanning {

    static func pieces(
        isForBackPage: Bool,
        captureBackWhenStartingFront: Bool
    ) -> [IDCPiece] {
        if isForBackPage { return [.passportBack] }
        if captureBackWhenStartingFront { return [.passportFront, .passportBack] }
        return [.passportFront]
    }

    static func captureBackWhenStartingFront(
        bouncerRequirement: BouncerRequirement,
        passport: PassportData?,
        passportQualityCheck: PassportQualityCheck?
    ) -> Bool {
        ScanDocsCoordinator.getPassportScanRequirement(
            bouncerRequirement: bouncerRequirement,
            passport: passport,
            passportQualityCheck: passportQualityCheck
        ).captureBack
    }
}
