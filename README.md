# ATCaptureKit

The passport and selfie capture flow (front page, back page, selfie, gallery and file upload, review and failure sheets), extracted from the VDC app's `VDCApp/Modules/IdentityCapture` into a standalone SPM package. The remote is `atlyslabs/ATCaptureKit` (branch `master`, not tagged yet).

```swift
.package(url: "https://github.com/atlyslabs/ATCaptureKit.git", branch: "master")
```

Architecture rule this package follows: **only the capture screens live here.** On-device document and face checks, OCR, upload, and the visa-funnel storage that used to sit next to this flow are the host app's job.

## What's in here

- `Sources/ATCaptureKit/Domain` — the pieces (`IDCPiece`: `.passportFront`, `.passportBack`, `.selfie`), `IDCConfiguration`, `IDCCallbacks`, `IDCVerifier`, and the scan-engine protocols the host implements.
- `Sources/ATCaptureKit/Presentation` — the flow. `IDCFactory` and `IDCFlowView` are the entry points. The passport scan, the flip between front and back, the selfie scan, the review sheet, and the failure sheet live under `Presentation/Views`.
- `Sources/ATCaptureKit/Core` — camera session and permission gate, haptics, image and PDF pickers, and `IDCAnalytics`. `IDCNoopScanEngineProvider` is internal and only covers previews and the debug harness; a live scan through it never fires.
- `Sources/ATCaptureKit/Debug` — `IdentityCaptureDebugView`, a harness for driving the flow without a host. It is compiled into the library.
- `AppIntegration/IdentityCaptureHost` — the Atlas visa-funnel adapter (`ApplicationCaptureLauncher`, the OCR client). It is not a target of this package. It mirrors the app's `VDCApp/Modules/IdentityCaptureHost`, which builds against this package: the launcher passes `scanEngines:`, `Engines/VDCCaptureScanEngines.swift` adapts the app's Vision analyzers, and `Core/VDCCaptureAnalytics.swift` is the analytics reporter.

Passport detection art, corner brackets, and the camera preview moved in with the flow. They used to live in the KYC module.

## Bootstrapping a host

1. Set `IDCAnalytics.reporter` once at launch. The property is weak, so the host keeps the object alive. Events are dropped while it is `nil`.

   ```swift
   final class CaptureAnalytics: IDCAnalyticsReporting {
       func report(event name: String, parameters: [String: Any?]) {
           Analytics.track(name, parameters.compactMapValues { $0 })
       }
   }

   IDCAnalytics.reporter = CaptureAnalytics()
   ```

   Event names: `identity_capture_started`, `identity_capture_piece_captured`, `identity_capture_piece_verified`, `identity_capture_piece_rejected`, `identity_capture_completed`, `identity_capture_exited`. Each one carries `host_context` from `IDCConfiguration.analyticsContext`.

2. Build an `IDCConfiguration` for the pieces this session should capture, in order. Per-piece title, subtitle, and eyebrow go on `copy`. `headerAccessory` is an optional SwiftUI view under the header.

   ```swift
   var configuration = IDCConfiguration(
       pieces: [.passportFront, .passportBack],
       flowTitle: "Scan passport",
       analyticsContext: "profile_passport"
   )
   configuration.showsBack = true
   configuration.allowUploadFromDevice = true
   configuration.progress = .segments(count: 2, filled: 1)
   configuration.copy[.passportFront] = IDCCaptureCopy(
       title: "Scan the photo page",
       subtitle: "Lay it flat inside the frame"
   )
   ```

3. Pass a verifier and a scan-engine provider into `IDCFactory`. The verifier runs after the user confirms a photo. The engines run during the live scan and on a gallery upload.

   ```swift
   let controller = IDCFactory.makeViewController(
       configuration: configuration,
       verifier: PassportUploadVerifier(),
       scanEngines: CaptureEngines(),
       callbacks: IDCCallbacks(
           onComplete: { results, payloads in /* every piece verified */ },
           onExit: { /* user backed out */ }
       )
   )
   ```

   `IDCFactory.push(from:configuration:verifier:scanEngines:callbacks:)` pushes that controller and dismisses it on exit. A SwiftUI host builds an `IDCFlowViewModel` with the same four arguments and renders `IDCFlowView(viewModel:)`.

   `IDCVerifier.verify` returns `.verified(payload:)`, `.rejected(reason:)`, or `.failed(message:)`. A rejection brings the failure sheet and lets the user scan again. A failure is the transport case, with retry. The payload from `.verified` is handed back on `onComplete` keyed by piece.

## What the host must still provide

- An `IDCScanEngineProvider`. `makePassportEngine()` and `makeSelfieEngine()` each return a fresh engine for one screen. Live capture completes when the engine sets `capturedImage` on `IDCPassportScanState` or `IDCSelfieScanState` (set `capturedFieldDetections` first so the overlay can read it). `validateUpload` accepts a gallery or file image, or returns an `IDCCaptureFailure`. `processFrame` is called on the camera's video queue. This package does not ship the Vision or TFLite models; those stay in the app.
- An `IDCVerifier` that uploads or checks the confirmed image. The package does not talk to the network.
- `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in the host's `Info.plist`. The primer and the denied-camera panel are in the package; the usage strings are not.
- `IDCAnalytics.reporter`, if the host wants the events above. Leaving it unset drops them.

`Image("reminder_bell")` and the names in `IDCTheme.Assets` still read the main bundle. They build, and they render only when the host's asset catalog contains them.

## Also public

- `IDCPiece`, `IDCCaptureResult`, `IDCCaptureSource`, `IDCVerificationOutcome`, `IDCCaptureFailure` — the values a verifier and a callback see.
- `IDCProgressStyle` — `.segments(count:filled:)`, `.fraction`, or `.hidden`.
- `IDCFieldDetections` and `IDCPassportGuidance` — what a passport engine publishes while the camera runs. `IDCSelfieGuidance` lists the coaching strings the selfie screen already knows how to show; an engine can pass those raw values through `IDCSelfieScanState.statusMessage`.

## Deliberately out of scope

- **On-device passport and selfie analysis.** The app's Vision and TFLite analyzers (`PassportPhotoAnalyzer`, `SelfiePhotoAnalyzer`, and the upload analyzers) stay in the host and adapt to `IDCPassportScanEngine` and `IDCSelfieScanEngine`.
- **OCR and storage.** `IDCDefaultOCRVerifier`, `IDCOCRVerificationMapper`, and `IDCVisaPassportVerifier` live in `AppIntegration` and are not compiled here. A profile or KYC host passes its own upload closure as the verifier.
- **The visa funnel.** `ApplicationCaptureLauncher` and the passport and selfie host view controllers know about `UserData`, `PassportData`, and bouncer requirements. They call this package. They do not move into it.
- **KYC onboarding around the scan.** Gmail connect, ITR connect, and the onboarding coordinator are not capture screens. A host that reaches this flow from KYC presents `IDCFlowView` for the passport step and the selfie step and keeps the rest of that session itself.
