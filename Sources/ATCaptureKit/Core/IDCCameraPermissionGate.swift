import SwiftUI

@MainActor
final class IDCCameraPermissionGate: ObservableObject {
    @Published var cameraReady = false
    @Published var cameraDenied = false
    @Published var cameraRestricted = false
    @Published var showsPrimer = false
    @Published var awaitingSystemPrompt = false

    var cameraBlocked: Bool { cameraDenied || cameraRestricted }

    private static let primerSettleNanoseconds: UInt64 = 400_000_000

    func resolve(configuration: IDCConfiguration) {
        #if DEBUG
        if configuration.debugSimulateCameraDenied {
            cameraDenied = true
            return
        }
        if configuration.debugSimulateCameraPrimer {
            showsPrimer = true
            return
        }
        #endif
        switch IDCCameraPermission.currentStatus() {
        case .granted: cameraReady = true
        case .denied: cameraDenied = true
        case .restricted: cameraRestricted = true
        case .notDetermined: showsPrimer = true
        }
    }

    func requestAccess() async {
        showsPrimer = false
        awaitingSystemPrompt = true
        try? await Task.sleep(nanoseconds: Self.primerSettleNanoseconds)
        let status = await IDCCameraPermission.ensureAccess()
        awaitingSystemPrompt = false
        cameraReady = status == .granted
        cameraDenied = status == .denied
        cameraRestricted = status == .restricted
    }
}
