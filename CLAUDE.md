# IdentityCapture package: working context

This folder is the Swift package `IdentityCapture`, copied from the Atlys iOS app's Identity Capture module so it can build on its own. The app still compiles `VDCApp/Modules/IdentityCapture`. This copy is not linked yet.

## Locations

| What | Path |
|---|---|
| Package | `/Users/aravindh/Desktop/Atlys/IdentityCapture`, git on `master` at `f2708b2`, remote `atlyslabs/ATCaptureKit` |
| Package sources | `Sources/IdentityCapture`, copied from `vdcios/VDCApp/Modules/IdentityCapture` |
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

- On-device checks. `IDCPassportUploadAnalyzer` and `IDCSelfieUploadAnalyzer` wrap `PassportUploadAnalyzer` and `SelfieUploadAnalyzer`. The scan screens also take `PassportPhotoAnalyzer` and `SelfiePhotoAnalyzer`. `PassportOcrSettings` and `SelfieCaptureSettings` are the settings those checkers use. The package should take a checker protocol. The app keeps the Vision implementation.
- Passport guide art. `IDCPassportScanScreen` and `IDCPassportFlipView` draw `KYCPassportDetectionOverlay` and `KYCPassportDetectionVisual` from `KYCPassportScanView.swift`. That art can move into this package, or the app can draw it through a small render hook. It should not pull the KYC module in.
- Analytics. `IDCAnalytics` calls `AnalyticsEventManager.sharedInstance.logPostHogEvent`. A reporting protocol replaces that. The app forwards the events.
- Navigation. `IDCNavigator.push` downcasts to `AVNavigationViewController` and builds one when it has to present. AIProfile's host already presents on a plain `UINavigationController` and does not call `IDCNavigator`. The package should push and present on `UINavigationController`. The app keeps the `AVNavigationViewController` behavior at its own call sites.
- `Image("reminder_bell")` reads the app catalog.

## Status as of 2026-10-15: linked into the app (uncommitted)

The app on `feature-profile-ai-spm` now uses this package instead of `VDCApp/Modules/IdentityCapture`. All of this is uncommitted in both repos.

- **App wiring.** `VDCApp.xcodeproj` has an `XCLocalSwiftPackageReference` to `../IdentityCapture` with product `ATCaptureKit` on the VDCApp target. It is local because the public-access changes below are not pushed. Switch it to the remote once they are. The app's module folder is now `VDCApp/Modules/IdentityCaptureHost` (synchronized group `1DCA97002F5800000000A001`). The 33 files that moved into this package are deleted there. `Application/` and the OCR `Data/` files stay as app code.
- **App-side engine.** `Engines/VDCCaptureScanEngines.swift` implements `IDCScanEngineProvider`. It takes `ocrSettings` and the two selfie capture settings, which used to be `IDCConfiguration` fields. The passport engine creates a fresh `PassportFrameProcessor` per `startLive`, sharing one `PassportUploadAnalyzer` model with `validateUpload`, and forwards its `@Published` state into `IDCPassportScanState`. The selfie engine does the same with `SelfieFrameProcessor` and `SelfieUploadAnalyzer`. `restartLive` maps to the processor's `restart()`, and the viewfinder is stored until a processor exists. There are guidance and field-detection converters both ways, and the old `idcFailure` mappings.
- **Other app pieces.** `Core/VDCCaptureAnalytics.install()` runs in AppDelegate and keeps the reporter alive, since the package holds it weakly. `Application/ApplicationCaptureNavigator` is the app's `AVNavigationViewController`-aware push and dismiss, so this package's `IDCNavigator` stays internal. The launcher, both KYC capture views, the Profile V3 identity-capture adapter and both debug-menu entry points pass `VDCCaptureScanEngines`. `AppIntegration/IdentityCaptureHost` here mirrors the app folder.
- **Made public in this package**, because the app uses them:
  - the `IDCConfiguration` knobs: top bar, trailing button, reminder link, `skip`, `analyticsSubjectId`, `onReminderSet` and `selfieSubjectName`;
  - `IDCSkipOption`, `IDCScanTopBarPlacement`, the `IDCCallbacks` properties, `IDCCaptureResult.fieldDetections` and `IDCPiece.isPassport`;
  - the `IDCCaptureFailure` presets and `selfieIssue`, `IDCVerificationOutcome.verified` and `IDCPassThroughVerifier`;
  - `IDCStrings.Failure.unreadablePhotoMessage`, `IDCStrings.Verifier.*` and `IDCStrings.CTA.skip`;
  - `IDCFlowViewModel.updateProgress` and `updateFlowTitle`.
- **Debug harness.** `IdentityCaptureDebugHostingController` is public with `init(scanEngines:onClose:)`, so live debug flows use the app's engines instead of the no-op ones. It is still `#if DEBUG`, and so are both app call sites.
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
