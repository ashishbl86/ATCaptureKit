import ATCaptureKit
import Alamofire
import Foundation

enum IDCOCRVerificationMapper {

    static var offlineOutcome: IDCVerificationOutcome? {
        guard NetworkReachabilityManager()?.isReachable == false else { return nil }
        return .failed(message: IDCStrings.Verifier.offline)
    }

    static func outcome(for error: OCRError) -> IDCVerificationOutcome {
        if NetworkReachabilityManager()?.isReachable == false {
            return .failed(message: IDCStrings.Verifier.offline)
        }
        if isRetriableTransportError(error) {
            return .failed(message: IDCStrings.Verifier.offline)
        }
        return .rejected(reason: IDCStrings.Verifier.unreadablePassport)
    }

    static func uploadFailedOutcome(_ error: Error) -> IDCVerificationOutcome {
        if NetworkReachabilityManager()?.isReachable == false {
            return .failed(message: IDCStrings.Verifier.offline)
        }
        return .failed(message: IDCStrings.Verifier.uploadFailed)
    }

    private static func isRetriableTransportError(_ error: OCRError) -> Bool {
        let message = error.errorString.lowercased()
        let retriableKeywords = [
            "network", "internet", "timeout", "timed out", "connection",
            "offline", "502", "503", "504", "500", "could not connect",
            "urlsession", "nsurlerror"
        ]
        return retriableKeywords.contains { message.contains($0) }
    }
}
