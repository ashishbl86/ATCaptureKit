import Alamofire
import UIKit
import SwiftyJSON

actor IDCDefaultOCRVerifier: IDCVerifier {

    private let citizenshipCountryCode: String
    private let travelerId: String
    private var passportData = PassportData()

    init(
        citizenshipCountryCode: String = (Locale.current.avRegionCode ?? "IN").uppercased(),
        travelerId: String = ""
    ) {
        self.citizenshipCountryCode = citizenshipCountryCode
        self.travelerId = travelerId
    }

    func verify(_ result: IDCCaptureResult) async -> IDCVerificationOutcome {
        guard result.piece.isPassport else {
            return .verified(payload: nil)
        }
        if let offline = IDCOCRVerificationMapper.offlineOutcome { return offline }

        let isForBackPage = result.piece == .passportBack
        let existing = passportData

        let ocrResult: Result<(PassportData, UIImage, ImageQualityChecks, JSON), OCRError> =
            await withCheckedContinuation { continuation in
                APIManager.sharedInstance.sendImageToOcrEngine(
                    capturedDocument: .image(result.image),
                    isImageCropped: true,
                    citizenshipCountryCode: citizenshipCountryCode,
                    isForBackPage: isForBackPage,
                    travelerId: travelerId,
                    existingPassportData: existing,
                    checkTravelDoc: false
                ) { continuation.resume(returning: $0) }
            }

        switch ocrResult {
        case .success(let (freshPassportData, _, qualityChecks, _)):
            if let failure = qualityChecks.getFailedQualityCheckMessage(documentName: "Passport") {
                return .rejected(reason: failure)
            }
            passportData = freshPassportData
            return .verified(payload: freshPassportData)

        case .failure(let error):
            return IDCOCRVerificationMapper.outcome(for: error)
        }
    }
}
