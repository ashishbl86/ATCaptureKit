import Alamofire
import SwiftyJSON
import UIKit

actor IDCVisaPassportVerifier: IDCVerifier {

    private let applicationId: String
    private let scanLocation: String
    private let coTravelerId: String?
    private let checkTravelDoc: Bool
    private var passportData: PassportData

    init(context: ApplicationCaptureContext) {
        applicationId = context.applicationId
        scanLocation = context.scanLocation.rawValue
        coTravelerId = context.coTravelerId
        checkTravelDoc = context.passportOcrSettings?.enableTravelDocCheck ?? false
        passportData = context.existingPassport
    }

    func verify(_ result: IDCCaptureResult) async -> IDCVerificationOutcome {
        guard result.piece.isPassport else {
            return .verified(payload: nil)
        }

        let isForBackPage = result.piece == .passportBack
        let existing = passportData

        let citizenshipResult = ApplicationCapturePassportStorage.citizenshipCountryCode(applicationId: applicationId)
        guard case .success(let citizenshipCountryCode) = citizenshipResult else {
            let message: String
            if case .failure(let error) = citizenshipResult {
                message = error.localizedDescription
            } else {
                message = IDCStrings.Verifier.unreadablePassport
            }
            return .rejected(reason: message)
        }

        let travelerId = coTravelerId ?? (UserData.currentUser?.userUid ?? "")

        let ocrResult: Result<(PassportData, UIImage, ImageQualityChecks, JSON), OCRError> =
            await withCheckedContinuation { continuation in
                APIManager.sharedInstance.sendImageToOcrEngine(
                    capturedDocument: .image(result.image),
                    isImageCropped: true,
                    citizenshipCountryCode: citizenshipCountryCode,
                    isForBackPage: isForBackPage,
                    travelerId: travelerId,
                    existingPassportData: existing,
                    checkTravelDoc: checkTravelDoc
                ) { continuation.resume(returning: $0) }
            }

        switch ocrResult {
        case .success(var (freshPassportData, image, qualityChecks, _)):
            if let failure = qualityChecks.getFailedQualityCheckMessage(documentName: "Passport") {
                return .rejected(reason: failure)
            }
            switch await ApplicationCapturePassportStorage.attachUploadedImage(
                passportData: &freshPassportData,
                image: image,
                isForBackPage: isForBackPage,
                scanLocation: scanLocation,
                coTravelerId: coTravelerId
            ) {
            case .success:
                passportData = freshPassportData
                return .verified(payload: freshPassportData)
            case .failure(let error):
                return IDCOCRVerificationMapper.uploadFailedOutcome(error)
            }

        case .failure(let error):
            return IDCOCRVerificationMapper.outcome(for: error)
        }
    }
}
