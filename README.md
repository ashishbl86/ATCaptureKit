# ATCaptureKit

The passport and selfie capture flow (front page, back page, selfie, gallery and file upload, review and failure sheets), extracted from the VDC app's `VDCApp/Modules/IdentityCapture` into a standalone SPM package. The remote is `atlyslabs/ATCaptureKit` (branch `master`, not tagged yet).

```swift
.package(url: "https://github.com/atlyslabs/ATCaptureKit.git", branch: "master")
```

Architecture rule this package follows: **the package does everything except run the models.** It owns the camera, every screen, the on-device checks (image pre-processing, model output decoding, Vision face checks, brightness and blur) and every capture decision. It also ships the three TFLite models. The host only runs a model when asked: it gets a model file once, then turns an input tensor into an output tensor. OCR, upload and visa-funnel storage stay with the host.

## What's in here

- `Sources/ATCaptureKit/Domain`:
  - the pieces (`IDCPiece`: `.passportFront`, `.passportBack`, `.selfie`), `IDCConfiguration`, `IDCCallbacks` and `IDCVerifier`;
  - the model-runner seam (`IDCInference.swift`) and the per-flow check switches (`IDCChecks.swift`);
  - `IDCUploadCheck`, which turns photo findings into failures.
- `Sources/ATCaptureKit/Analysis` — the on-device pipeline, ported from the VDC app:
  - the passport detector and glare classifier: YOLOv8 decoding, per-class thresholds, NMS, the travel-document rule, the finger check over the MRZ details;
  - the selfie checks: Vision landmarks, phone tilt, framing hysteresis, the 4-way classifier;
  - the tensor pre-processing (vImage rotate, scale and letterbox, normalisation);
  - brightness and blur;
  - the analyzers the screens use.
- `Sources/ATCaptureKit/Presentation` — the flow. `IDCFactory` and `IDCFlowView` are the entry points. The passport scan, the flip between front and back, the selfie scan, the review sheet and the failure sheet live under `Presentation/Views`.
- `Sources/ATCaptureKit/Core`:
  - camera session and permission gate;
  - the live-scan state machines (`IDCPassportLiveScan`, `IDCSelfieLiveScan`);
  - the frame renderer that rotates and crops the captured still;
  - the capture chime, haptics, image and PDF pickers, and `IDCAnalytics`.
- `Sources/ATCaptureKit/Resources`:
  - `passport_multi_class_detection.tflite`, `glare_model_fp16.tflite` and `selfie_model.tflite`;
  - `scanSuccess.mp3`.
- `Sources/ATCaptureKit/Debug` — `IdentityCaptureDebugView`, a harness for driving the flow without a host. It is compiled into the library.
- `AppIntegration/IdentityCaptureHost` — the Atlas visa-funnel adapter (`ApplicationCaptureLauncher`, the OCR client). It is not a target of this package.
  - It mirrors the app's `VDCApp/Modules/IdentityCaptureHost`, which builds against this package.
  - `Engines/VDCTFLiteRunner.swift` is the app's model runner and settings mapping.
  - `Core/VDCCaptureAnalytics.swift` is the analytics reporter.

Passport detection art, corner brackets, and the camera preview moved in with the flow. They used to live in the KYC module.

## Bootstrapping a host

1. Register a model runner once at launch. This is the only ML code a host writes. With TensorFlow Lite (`pod 'TensorFlowLiteSwift'`):

   ```swift
   import ATCaptureKit
   import TensorFlowLite

   final class TFLiteRunner: IDCModelRunner {
       func loadModel(at url: URL) throws -> IDCLoadedModel { try TFLiteModel(url: url) }
   }

   private final class TFLiteModel: IDCLoadedModel {
       private let interpreter: Interpreter

       init(url: URL) throws {
           var options = Interpreter.Options()
           options.threadCount = 1
           interpreter = try Interpreter(modelPath: url.path, options: options)
           try interpreter.allocateTensors()
       }

       func run(_ input: Data) throws -> IDCTensor {
           try interpreter.copy(input, toInputAt: 0)
           try interpreter.invoke()
           let output = try interpreter.output(at: 0)
           return IDCTensor(data: output.data, shape: output.shape.dimensions)
       }
   }

   IDCInference.runner = TFLiteRunner()
   ```

   - **What the package passes in:** the URL of one of its own bundled models (`IDCModel`), loaded off the main thread when a capture screen appears and released with the screen. Each input is Float32 NHWC data, already resized and normalised.
   - **What the host returns:** output tensor 0 with its shape.
   - **Threading:** calls to one loaded model never overlap.
   - **Without a runner:** live scans never fire, and uploads fail with "scanner not ready" after a 5-second wait.

2. Set `IDCAnalytics.reporter` once at launch. The property is weak, so the host keeps the object alive. Events are dropped while it is `nil`.

   ```swift
   final class CaptureAnalytics: IDCAnalyticsReporting {
       func report(event name: String, parameters: [String: Any?]) {
           Analytics.track(name, parameters.compactMapValues { $0 })
       }
   }

   IDCAnalytics.reporter = CaptureAnalytics()
   ```

   Event names: `identity_capture_started`, `identity_capture_piece_captured`, `identity_capture_piece_verified`, `identity_capture_piece_rejected`, `identity_capture_completed`, `identity_capture_exited`. Each one carries `host_context` from `IDCConfiguration.analyticsContext`.

3. Build an `IDCConfiguration` for the pieces this session should capture, in order.
   - Per-piece title, subtitle, and eyebrow go on `copy`.
   - `headerAccessory` is an optional SwiftUI view under the header.
   - `passportChecks` turns the glare and finger checks off.
   - `selfieChecks` and `selfieUploadChecks` choose the selfie rules for live and uploaded photos. Uploads use the live rules when `selfieUploadChecks` is `nil`.

   ```swift
   var configuration = IDCConfiguration(
       pieces: [.passportFront, .passportBack],
       flowTitle: "Scan passport",
       analyticsContext: "profile_passport"
   )
   configuration.showsBack = true
   configuration.allowUploadFromDevice = true
   configuration.progress = .segments(count: 2, filled: 1)
   configuration.passportChecks = IDCPassportChecks(glare: false, fingers: true)
   configuration.copy[.passportFront] = IDCCaptureCopy(
       title: "Scan the photo page",
       subtitle: "Lay it flat inside the frame"
   )
   ```

4. Pass a verifier into `IDCFactory`. The verifier runs after the user confirms a photo.

   ```swift
   let controller = IDCFactory.makeViewController(
       configuration: configuration,
       verifier: PassportUploadVerifier(),
       callbacks: IDCCallbacks(
           onComplete: { results, payloads in /* every piece verified */ },
           onExit: { /* user backed out */ }
       )
   )
   ```

   - `IDCFactory.push(from:configuration:verifier:callbacks:)` pushes that controller and dismisses it on exit.
   - A SwiftUI host builds an `IDCFlowViewModel` with the same three arguments and renders `IDCFlowView(viewModel:)`.
   - `IDCVerifier.verify` returns `.verified(payload:)`, `.rejected(reason:)`, or `.failed(message:)`. A rejection brings the failure sheet and lets the user scan again. A failure is the transport case, with retry. The payload from `.verified` is handed back on `onComplete` keyed by piece.

## What the host must still provide

- An `IDCModelRunner` (above), and the TFLite runtime it uses. TFLite ships for iOS through CocoaPods only, so the package cannot depend on it. A host that already links TFLite for other models would also clash with a second copy.
- An `IDCVerifier` that uploads or checks the confirmed image. The package does not talk to the network.
- `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` in the host's `Info.plist`. The primer and the denied-camera panel are in the package; the usage strings are not.
- `IDCAnalytics.reporter`, if the host wants the events above. Leaving it unset drops them.

`Image("reminder_bell")` and the names in `IDCTheme.Assets` still read the main bundle. They build, and they render only when the host's asset catalog contains them.

## Also public

- `IDCPiece`, `IDCCaptureResult`, `IDCCaptureSource`, `IDCVerificationOutcome`, `IDCCaptureFailure` — the values a verifier and a callback see. `IDCCaptureResult.fieldDetections` (`IDCFieldDetections`) holds the passport photo, signature and MRZ boxes, normalised to the captured crop.
- `IDCProgressStyle` — `.segments(count:filled:)`, `.fraction`, or `.hidden`.
- `IDCModel`, `IDCTensor`, `IDCModelRunner`, `IDCLoadedModel`, `IDCInference` — the model-runner seam. `IDCModel.url` also lets the host load the same bundled files elsewhere.
- `IDCPassportChecks`, `IDCSelfieChecks` (`.standard`, `.none`) — the check switches.

## Deliberately out of scope

- **The TFLite runtime.** The host runs the models (see above).
- **OCR and storage.** `IDCDefaultOCRVerifier`, `IDCOCRVerificationMapper`, and `IDCVisaPassportVerifier` live in `AppIntegration` and are not compiled here. A profile or KYC host passes its own upload closure as the verifier.
- **The visa funnel.** `ApplicationCaptureLauncher` and the passport and selfie host view controllers know about `UserData`, `PassportData`, and bouncer requirements. They call this package. They do not move into it.
- **KYC onboarding around the scan.** Gmail connect, ITR connect, and the onboarding coordinator are not capture screens. A host that reaches this flow from KYC presents `IDCFlowView` for the passport step and the selfie step and keeps the rest of that session itself.
