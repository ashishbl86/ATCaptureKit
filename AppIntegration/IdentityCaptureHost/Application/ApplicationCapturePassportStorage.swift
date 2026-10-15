import UIKit

enum ApplicationCapturePassportStorage {

    static func citizenshipCountryCode(applicationId: String) -> Result<CountryCode, Error> {
        guard let currentUser = UserData.currentUser else {
            return .failure(GeneralError(errorString: "User data not available"))
        }
        if let citizenshipCountryCode = currentUser.applications[applicationId]?.citizenshipCountryCode {
            return .success(citizenshipCountryCode)
        }
        if let citizenshipCountryCode = currentUser.citizenshipDeduced?.countryCode {
            return .success(citizenshipCountryCode)
        }
        return .failure(GeneralError(errorString: "Failed to get the citizenship of user"))
    }

    static func passportStorageFileName(
        isForBackPage: Bool,
        scanLocation: String,
        coTravelerId: String?,
        fileExtension: String,
        suffix: String? = nil
    ) -> String {
        guard let currentUser = UserData.currentUser else { return "" }
        let prefix = isForBackPage ? "passport_back" : "passport_front"
        let travelerId = coTravelerId ?? currentUser.userUid

        var fileName = "\(prefix)_iOS_\(scanLocation)_\(travelerId)_\(String.randomString(length: 5))"
        if let suffix {
            fileName.append("_\(suffix)")
        }
        fileName.append(".\(fileExtension)")

        if let coTravelerId {
            return currentUser.userUid + "/\(coTravelerId)" + "/\(fileName)"
        }
        return currentUser.userUid + "/\(fileName)"
    }

    static func attachUploadedImage(
        passportData: inout PassportData,
        image: UIImage,
        isForBackPage: Bool,
        scanLocation: String,
        coTravelerId: String?
    ) async -> Result<Void, Error> {
        let fileName = passportStorageFileName(
            isForBackPage: isForBackPage,
            scanLocation: scanLocation,
            coTravelerId: coTravelerId,
            fileExtension: "jpg"
        )
        guard !fileName.isEmpty else {
            return .failure(GeneralError(errorString: "User data not available"))
        }

        let uploadResult: Result<URL?, UploadError> = await withCheckedContinuation { continuation in
            StorageService.uploadDocument(document: .image(image), filename: fileName) { continuation.resume(returning: $0) }
        }

        switch uploadResult {
        case .success:
            if isForBackPage {
                passportData.lastPageImageUrl = fileName
                passportData.lastPageImageUploadedAt = Date()
            } else {
                passportData.imageUrl = fileName
                passportData.imageUploadedAt = Date()
            }
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
}
