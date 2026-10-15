import Foundation

enum ApplicationCaptureLocation: String {
    case funnel
    case review
    case schengen
    case docVault = "docVault"
    case fastTrack = "fast_track"
    case infinity
    case usPostCheckout = "us_post_checkout"
    case other

    static func from(_ rawLocation: String) -> ApplicationCaptureLocation {
        if let location = ApplicationCaptureLocation(rawValue: rawLocation) {
            return location
        }
        #if DEBUG
        assertionFailure("Unknown capture location \"\(rawLocation)\" — add a case to ApplicationCaptureLocation")
        #endif
        return .other
    }
}

struct ApplicationCaptureContext {
    let applicationId: String
    let scanLocation: ApplicationCaptureLocation
    let coTravelerId: String?
    let existingPassport: PassportData
    let passportOcrSettings: PassportOcrSettings?
    let selfieLiveCaptureSettings: SelfieCaptureSettings?
    let selfieUploadCaptureSettings: SelfieCaptureSettings?

    init(
        applicationId: String,
        scanLocation: ApplicationCaptureLocation = .funnel,
        coTravelerId: String? = nil,
        existingPassport: PassportData = PassportData(),
        passportOcrSettings: PassportOcrSettings? = nil,
        selfieLiveCaptureSettings: SelfieCaptureSettings? = nil,
        selfieUploadCaptureSettings: SelfieCaptureSettings? = nil
    ) {
        self.applicationId = applicationId
        self.scanLocation = scanLocation
        self.coTravelerId = coTravelerId
        self.existingPassport = existingPassport
        self.passportOcrSettings = passportOcrSettings
        self.selfieLiveCaptureSettings = selfieLiveCaptureSettings
        self.selfieUploadCaptureSettings = selfieUploadCaptureSettings
    }
}
