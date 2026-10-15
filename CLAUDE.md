# IdentityCapture package: working context

This folder is the Swift package `IdentityCapture`, copied from the Atlys iOS app's Identity Capture module so it can build on its own. The app still compiles `VDCApp/Modules/IdentityCapture`. This copy is not linked yet.

## Locations

| What | Path |
|---|---|
| Package | `/Users/aravindh/Desktop/Atlys/IdentityCapture`, git on `master`, no commits yet, no remote |
| Package sources | `Sources/IdentityCapture`, copied from `vdcios/VDCApp/Modules/IdentityCapture` |
| App repo | `/Users/aravindh/Desktop/Atlys/vdcios`, branch `feature-profile-ai-spm`, HEAD `c2228520b` |
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
