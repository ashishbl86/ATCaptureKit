import AVFoundation
import UIKit

enum IDCCameraPermission {

    enum Status {
        case granted
        case denied
        case restricted
        case notDetermined
    }

    static func currentStatus() -> Status {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    static func ensureAccess() async -> Status {
        let status = currentStatus()
        guard status == .notDetermined else { return status }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .granted : .denied
    }

    @MainActor
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
