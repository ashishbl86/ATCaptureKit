import UIKit

struct IDCSelfieApplicationVerifier: IDCVerifier {

    let context: ApplicationCaptureContext

    func verify(_ result: IDCCaptureResult) async -> IDCVerificationOutcome {
        guard result.piece == .selfie else { return .verified }
        if let offline = IDCOCRVerificationMapper.offlineOutcome { return offline }

        switch await PhotoCoordinator.storeCapturedPhoto(
            image: result.image,
            forCoTraveler: context.coTravelerId,
            applicationId: context.applicationId,
            captureLocation: context.scanLocation.rawValue
        ) {
        case .success:
            return .verified
        case .failure(let error):
            return IDCOCRVerificationMapper.uploadFailedOutcome(error)
        }
    }
}
