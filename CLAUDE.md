# IdentityCapture package: working context

This folder is the Swift package `ATCaptureKit` (folder name `IdentityCapture`), extracted from the Atlys iOS app's Identity Capture module. The app on `feature-profile-ai-spm` links it from GitHub `master`.

## Locations

| What | Path |
|---|---|
| Package | `/Users/aravindh/Desktop/Atlys/IdentityCapture`, git on `master`, last pushed `2b90a24`, remote `atlyslabs/ATCaptureKit` |
| Package sources | `Sources/ATCaptureKit`, extracted from `vdcios/VDCApp/Modules/IdentityCapture` |
| App repo | `/Users/aravindh/Desktop/Atlys/vdcios`, branch `feature-profile-ai-spm` (base `50ce1e9e1`) |
| Original module | `vdcios/VDCApp/Modules/IdentityCapture` |
| Profile package | `/Users/aravindh/Desktop/Atlys/AI-Profile` |

The copy matches the module on disk at that app HEAD. The last commit that touched the module is `1774fee30`. Language mode is Swift 5, matching the app target. `ATUIKit` is the only declared dependency, pinned the same way as AIProfile (`from: "1.3.7"`).

## Can AIProfile depend on this package directly?

Yes, for the capture flow. No, for this copy as it stands.

AIProfile already treats Identity Capture as a screen it presents. `ProfileV3IdentityCaptureHost` exists only because the flow lived in the app target. The package side passes pieces, copy, and a `verify` closure. The app side builds `IDCConfiguration`, `IDCFlowViewModel`, and `IDCFactory.makeViewController`. Once those types live in this package, AIProfile can `import IdentityCapture` and call them. The host protocol can go away for presentation. The app links both packages. There is no second copy of the flow.

The visa funnel is the other caller, and it stays in the app. `ApplicationCaptureLauncher` is used by the passport, selfie, co-traveller, Phoenix, DS-160, and post-checkout flows. That layer reads `UserData`, `PassportData`, and application analytics. It should keep calling this package. It should not move into a package that AIProfile depends on.

## What has to leave Sources before AIProfile can depend on it

`Application/` and the two OCR files now live in `AppIntegration/IdentityCaptureHost` and are not compiled by the package. They belong in the app, calling the package, the same way `AppIntegration/ProfileV3Host` calls AIProfile.

- `Application/` — `UserData`, `PassportData`, `AnalyticsEventManager`, bouncer requirements, Alamofire, and SwiftyJSON. `Application/README.md` lists the funnel call sites. `IDCVisaPassportVerifier` is here.
- `Data/IDCDefaultOCRVerifier.swift`, `Data/IDCOCRVerificationMapper.swift` — the app OCR client. `IDCFactory` no longer defaults to `IDCDefaultOCRVerifier()`. Callers pass a verifier.
- `Debug/IdentityCaptureDebugView.swift` is still in Sources. It names `FlashMessageGenerator` and `AVNavigationViewController`.

## Seams the capture flow still needs

The screens that remain in Sources still name app types. Each one is a small protocol, not a reason to keep the flow in the app.

- On-device checks. Done: the analyzer protocols (see "analysis split" below). The app keeps the Vision and TFLite implementation, `PassportOcrSettings` and `SelfieCaptureSettings`.
- Passport guide art. `IDCPassportScanScreen` and `IDCPassportFlipView` draw `KYCPassportDetectionOverlay` and `KYCPassportDetectionVisual` from `KYCPassportScanView.swift`. That art can move into this package, or the app can draw it through a small render hook. It should not pull the KYC module in.
- Analytics. `IDCAnalytics` calls `AnalyticsEventManager.sharedInstance.logPostHogEvent`. A reporting protocol replaces that. The app forwards the events.
- Navigation. `IDCNavigator.push` downcasts to `AVNavigationViewController` and builds one when it has to present. AIProfile's host already presents on a plain `UINavigationController` and does not call `IDCNavigator`. The package should push and present on `UINavigationController`. The app keeps the `AVNavigationViewController` behavior at its own call sites.
- `Image("reminder_bell")` reads the app catalog.

## Status as of 2026-10-15 (evening): model runner, the pipeline lives here (uncommitted, not pushed)

User ask: "using the tflite model from app via some callbacks and do all the processing and analysing inside the package itself … we will be using this idc module in another app … so don't need to duplicate". The user picked the runner option.

- **Host seam** (`Domain/IDCInference.swift`):
  - `IDCInference.runner` takes an `IDCModelRunner`. Its `loadModel(at:)` returns an `IDCLoadedModel`, and `run(Data) -> IDCTensor` turns a Float32 NHWC input into output 0 and its shape. That is the whole host ML surface. The README has the 25-line TensorFlow Lite version.
  - The models ship in `Resources` (`IDCModel`: `passport_multi_class_detection`, `glare_model_fp16`, `selfie_model`; 9.7 MB). `IDCModel.url` is public, so legacy app code can load the same files.
  - Without a runner, frames are skipped and uploads report "scanner not ready".
- **Per-flow checks:**
  - `IDCConfiguration.passportChecks` (`IDCPassportChecks`: glare, fingers).
  - `selfieChecks` and `selfieUploadChecks` (`IDCSelfieChecks`, with `.standard` = the app's old default and `.none`).
  - `checkHeadCover` is dropped, because the pipeline never read it.
- **Pipeline** (`Analysis/`), ported from the app (`TensorFlowInterpreter`, `PassportPhotoAnalyzer`, `PassportGlareAnalyzer`, `SelfiePhotoAnalyzer`, the upload validators):
  - `IDCImageTensorizer` and `IDCTensorReader`;
  - `IDCPassportInference` and `IDCSelfieInference`;
  - `IDCPixelBuffers` and `IDCImageOps`;
  - `IDCModelSlot`, which loads one model off the main thread through the runner and serialises its runs, replacing the app's per-analyzer `NSLock`s;
  - `IDCModelAnalyzers`, the provider the flow builds from the configuration and the registered runner.
- **Public surface:**
  - `IDCFactory` and `IDCFlowViewModel` dropped `analyzers:`.
  - `IdentityCaptureDebugHostingController(onClose:)`.
  - The analyzer protocols and their result types are internal again, and so is `IDCSelfieGuidance`.
- **Deliberate differences from the app:**
  - `IDCPixelBuffers.make(from:)` clears the context before drawing. The app's `UIImage.getCVPixelBuffer()` draws into an uninitialised buffer, so brightness, blur and the classifier input come out non-deterministic for many images. In the harness the original conversion changed between two calls on 42 of 56 test images, including opaque ones.
  - The `CIDetector` smile pass is gone. `hasSmile` only fed a debug log, so every decision is unchanged and each selfie frame is cheaper.
  - A malformed tensor from a host runner throws (`.failed`) instead of crashing.
- **Verified — parity harness** (`scratchpad/parity`):
  - It compiles the app's original pipeline, extracted verbatim, next to these files, with a fake `Interpreter` and a fake runner sharing scripted outputs.
  - It runs as a Mac Catalyst binary so Vision works; in the simulator Vision's face requests throw.
  - Result: 3,363 checks, 0 failures. The only change to the extracted copy is the same `clear` line.
  - Coverage:
    - 180 byte-identical input tensors (3 models × 4 buffer shapes × 5 rotations × 3 crops);
    - 12 passport scenarios × front/back × 3 check variants × 3 rotations, plus photos in 4 orientations and their upload verdicts and crops;
    - selfie upload and live on illustrated avatars where Vision finds faces (eyewear, face covered, teeth, one eye, head turned, good photo, come closer, too dark);
    - the async upload decisions;
    - the pixel helpers.
- **Verified — other checks:**
  - The state-machine harness passes all 68 checks again.
  - The package builds alone with no warnings outside ATUIKit.
  - A full VDCApp build succeeded through the local override. `Atlys.app` carries the models once, inside `ATCaptureKit_ATCaptureKit.bundle`.
  - Not run on a device.
- **App side:**
  - `Engines/VDCTFLiteRunner.swift` replaces `VDCCaptureAnalyzers.swift`: the runner, `install()` called from AppDelegate, mappings from `PassportOcrSettings` and `SelfieCaptureSettings`, and the `PassportFieldDetections` converter KYC uses.
  - The launcher sets the configuration checks.
  - The three `.tflite` files left `VDCApp/Assets/MLModels`, with 12 project-file entries removed.
  - `TensorFlowInterpreter.prepare(modelName:)` falls back to `IDCModel(rawValue:)?.url` for the legacy scanners, Schengen status, `PhotoAnalysisService` and the DS-160 ATCore bridge.

## Status as of 2026-10-15 (later): analysis split (uncommitted, not pushed; host side superseded by the model runner above)

User ask: "split all the flows post the spm gives the buffer to the app for processing and it gives back the results to the spm to show the results". The package now makes every capture decision; the app only analyzes. The analyzer protocols below became internal when the pipeline moved in.

- **Contract** (`Domain/IDCScanAnalyzer.swift`). `IDCAnalyzerProvider` vends `IDCPassportAnalyzer` and `IDCSelfieAnalyzer`. They replace the engine protocols and the `IDCPassportScanState` / `IDCSelfieScanState` objects the app used to write into.
  - Frames arrive on the video queue as `IDCCameraFrame`: the BGRA sample buffer in sensor orientation, the camera side, and the viewfinder size.
  - Results are `Sendable` values: `IDCPassportAnalysis`, `IDCPassportDetection`, `IDCFrameQuality`, `IDCSelfieAnalysis` and `IDCSelfiePhotoAnalysis`. Rects are normalized to the upright frame (90° clockwise from the buffer) with a top-left origin. `nil` means the model is still loading.
  - `frameQuality` is a separate call, so the expensive brightness and blur pass runs only on frames that reach the glare or good-frame step, as before.
  - `IDCPassportGuidance` is internal now. `IDCSelfieGuidance` is public, and its ranks stay internal.
- **Package-owned logic**, ported line for line from the app's `PassportFrameProcessor` and `SelfieFrameProcessor`:
  - `Core/IDCPassportLiveScan.swift`: ranks with a 0.4s hold, guide box `(0.025, 0.313, 0.95, 0.374)` with enter 0.78–0.82 and exit 0.73, 0.85 coverage, a 0.7 brightness split between light reflection and glare, the 10-frame streak, and the sharpest frame.
  - `Core/IDCSelfieLiveScan.swift`: ranks with a 0.4s hold, a 3s countdown at 0.1s ticks, the sharpest frame, and a crop to the viewfinder's aspect.
  - `Core/IDCFrameRenderer.swift`: CoreImage `.oriented(.right)` matches the app's vImage 90° clockwise rotation, checked pixel for pixel. Input is treated as sRGB, like the app's untagged rotated buffer.
  - `Domain/IDCUploadCheck.swift`: maps photo findings to `IDCCaptureFailure` and holds the app's orientation-aware crop.
  - `Core/IDCCaptureSound.swift` with `Resources/scanSuccess.mp3`. The target now declares resources, so `Bundle.module` exists.
  - The preview reports its size on layout (`IDCCameraPreview.onSizeChange`) instead of the analyzer reading a `UIView` on the camera queue.
- **Renames.** `scanEngines:` became `analyzers:` on `IDCFactory`, `IDCFlowViewModel` and `IdentityCaptureDebugHostingController(analyzers:onClose:)`. Also `IDCNoopAnalyzerProvider` and `IDCAnalyzerHolder`.
- **App side** (vdcios `IdentityCaptureHost/Engines/VDCCaptureAnalyzers.swift`, replacing `VDCCaptureScanEngines.swift`):
  - Thin adapters over `PassportPhotoAnalyzer` (TFLite inference plus `getMeanAndVarianceValueOnPixelBuffer`; that helper and its `laplacian` kernel are now `nonisolated` on the view controller) and `SelfiePhotoAnalyzer` (plus the document detector for uploads).
  - The selfie adapter owns the `CMMotionManager` and starts and stops it from the live hooks.
  - `SelfieImageData.liveScan` takes the viewfinder bounds (`CGRect`) instead of a `UIView`.
  - `PassportFrameProcessor`, `SelfieFrameProcessor` and the `*UploadAnalyzer` classes no longer serve the capture flow. Only the dead KYC scan views reference them.
- **Inherited quirk.** The upload crop is the app's `croppedImage(inRect:)`. For `.left` and `.down` photos it keeps one extra leading pixel, because the floating-point rotation runs before `CGImage.cropping`. The app does the same.
- **Verified:**
  - The package builds alone with no warnings outside ATUIKit.
  - A scratchpad harness compiled the real package files with a stub chime and ran 68 checks on a throwaway iOS 26.5 simulator, all passing. It covered renderer pixels, upload verdicts and crops, passport ranks, fit, streak and capture, and the selfie countdown, capture, camera switch and stop.
  - A full VDCApp Debug simulator build succeeded.
  - The app resolves this package from GitHub, so that build used a scratch workspace overriding it with a local copy in a folder named `ATCaptureKit`; the identity must match the remote's.
  - Not run on a device. Push this package (and update the app's pin) before the app's own Xcode build can see the app-side change.

## Status as of 2026-10-15: linked into the app (committed and pushed as `2b90a24`)

The app on `feature-profile-ai-spm` uses this package instead of `VDCApp/Modules/IdentityCapture`. The app now references it as `XCRemoteSwiftPackageReference` `atlyslabs/ATCaptureKit` on branch `master` (`CAD8DAD9…`). The Xcode folder references that overrode it locally were removed.

- **App wiring.** The app's module folder is now `VDCApp/Modules/IdentityCaptureHost` (synchronized group `1DCA97002F5800000000A001`). The 33 files that moved into this package are deleted there. `Application/` and the OCR `Data/` files stay as app code.
- **App-side engine (superseded by the analysis split above).** `Engines/VDCCaptureScanEngines.swift` implemented `IDCScanEngineProvider`. It takes `ocrSettings` and the two selfie capture settings, which used to be `IDCConfiguration` fields. The passport engine creates a fresh `PassportFrameProcessor` per `startLive`, sharing one `PassportUploadAnalyzer` model with `validateUpload`, and forwards its `@Published` state into `IDCPassportScanState`. The selfie engine does the same with `SelfieFrameProcessor` and `SelfieUploadAnalyzer`. `restartLive` maps to the processor's `restart()`, and the viewfinder is stored until a processor exists. There are guidance and field-detection converters both ways, and the old `idcFailure` mappings.
- **Other app pieces.** `Core/VDCCaptureAnalytics.install()` runs in AppDelegate and keeps the reporter alive, since the package holds it weakly. `Application/ApplicationCaptureNavigator` is the app's `AVNavigationViewController`-aware push and dismiss, so this package's `IDCNavigator` stays internal. The launcher, both KYC capture views, the Profile V3 identity-capture adapter and both debug-menu entry points pass `VDCCaptureScanEngines`. `AppIntegration/IdentityCaptureHost` here mirrors the app folder.
- **Made public in this package**, because the app uses them:
  - the `IDCConfiguration` knobs: top bar, trailing button, reminder link, `skip`, `analyticsSubjectId`, `onReminderSet` and `selfieSubjectName`;
  - `IDCSkipOption`, `IDCScanTopBarPlacement`, the `IDCCallbacks` properties, `IDCCaptureResult.fieldDetections` and `IDCPiece.isPassport`;
  - the `IDCCaptureFailure` presets and `selfieIssue`, `IDCVerificationOutcome.verified` and `IDCPassThroughVerifier`;
  - `IDCStrings.Failure.unreadablePhotoMessage`, `IDCStrings.Verifier.*` and `IDCStrings.CTA.skip`;
  - `IDCFlowViewModel.updateProgress` and `updateFlowTitle`.
- **Debug harness.** `IdentityCaptureDebugHostingController` is public with `init(analyzers:onClose:)` (it was `scanEngines:`), so live debug flows use the app's analyzers instead of the no-op ones. It is still `#if DEBUG`, and so are both app call sites.
- **Verified** on 2026-10-15. The package builds alone (`xcodebuild -scheme ATCaptureKit`, simulator), and a full VDCApp Debug simulator build with its own `-derivedDataPath` succeeds with no errors and no new warnings. The capture flows have not been run on a device.

## Status as of 2026-10-14

`swift build` for iOS Simulator succeeds (`xcodebuild -scheme IdentityCapture -destination 'generic/platform=iOS Simulator' build`). The package is not linked to the app or to AIProfile. No app call site has moved.

Seams now in Sources:

- `Domain/IDCScanEngine.swift` — `IDCPassportScanEngine`, `IDCSelfieScanEngine`, `IDCScanEngineProvider`, and the state objects the engines publish into. The app implements these over its Vision / TFLite analyzers (not written yet). `IDCConfiguration` no longer carries `ocrSettings` or the selfie capture settings; the app's engine owns them.
- `IDCFactory.push` / `makeViewController` and `IDCFlowViewModel` take `scanEngines:`. `IDCNoopScanEngineProvider` covers previews and the debug harness.
- `Core/IDCAnalytics.swift` — `IDCAnalytics.reporter` (`IDCAnalyticsReporting`). The app must set it or events are dropped.
- `IDCNavigator` pushes and presents on `UINavigationController`.
- Copied in from the app (no app dependency): camera service and preview (`IDCCameraService`), passport detection art, corner brackets, dotted divider, image picker, `Color(hex:)`, PDF-to-image, `IDCSelfieGuidance`.

Still open:

- `AppIntegration/IdentityCaptureHost` still calls the old `IDCFactory` signature and is not compiled. It needs `scanEngines:` and an engine adapter that maps `PassportScanGuidance`, `PassportFieldDetections` and the upload failures to the `IDC` types (`IDCSelfieGuidance` raw values match `SelfieScanMessage`).
- `Image("reminder_bell")` and the `IDCTheme.Assets` names read the main bundle, not the package. They build but need package resources (or a host-provided image) to render.
- `Debug/IdentityCaptureDebugView.swift` logs where it used to show `FlashMessageGenerator` toasts.
