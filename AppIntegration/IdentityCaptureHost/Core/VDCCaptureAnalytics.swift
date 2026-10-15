import ATCaptureKit
import Foundation

final class VDCCaptureAnalytics: IDCAnalyticsReporting {
    private static let shared = VDCCaptureAnalytics()

    static func install() {
        IDCAnalytics.reporter = shared
    }

    func report(event name: String, parameters: [String: Any?]) {
        AnalyticsEventManager.sharedInstance.logPostHogEvent(withName: name, parameters: parameters)
    }
}
