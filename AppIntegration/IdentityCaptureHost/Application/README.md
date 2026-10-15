# Application capture (visa funnel)

Classic visa / application funnel coordinators launch Identity Capture through this layer instead of pushing legacy view controllers directly.

## Entry point

- `ApplicationCaptureLauncher.presentPassport(...)` / `presentPassportModally(...)` — passport front/back (combined session with flip when the front step also needs back).
- `ApplicationCaptureLauncher.presentSelfie(...)` / `presentSelfieModally(...)` — new selfie capture (main + co-traveller).
- `ApplicationCapturePassportHostViewController` / `ApplicationCaptureSelfieHostViewController` — modal hosts for SwiftUI representables, the SPF upload sheet and coordinator roots.
- `ApplicationCapturePassportPlanning` — shared front/back piece list from bouncer + quality state.

Both passport and selfie entry points take an optional `copy:` (per-piece title/subtitle overrides) and
`onCapturedImage:` — the latter for hosts that run their own upload alongside the verifier's funnel storage.

## Funnel semantics

- Funnel-context sessions (`scanLocation == .funnel`) hide back on push (embedded breadcrumbs); modal funnel keeps IDC chrome without back.
- Non-funnel (review, schengen) keep back where configured; exit dismisses without completion callback.

## Migration checklist

- [x] `ScanDocsCoordinator` — main user passport
- [x] `PhotoCoordinator` — IDC selfie (reuse preview still legacy → IDC on “take new”)
- [x] `CoTravelersCaptureCoordinator` — co-traveller passport
- [x] `PhoenixFunnelContainerViewController` — main + co-traveller passport (modal, combined front/back)
- [x] `AVReviewView` — passport re-scan
- [x] `SinglePageFunnelContainerViewController` — passport upload
- [x] Schengen `PassportScanView`
- [x] `EntryFormFunnelHostingController` — passport scan
- [x] DocVault `PassportScannerView` / `SelfieScannerView` (image-only IDC, no visa OCR)
- [x] FastTrack passport + selfie (`FastTrackCaptureWrappers`, host VCs over the FTI page)
- [x] `USLoginDetailsCoordinator` — front + back as one session, login form swapped in on completion
- [x] `AVPostCheckoutViewController` — pending passport / photo re-upload
- [ ] `PhotoCoordinator` — IDC-native reuse-existing selfie preview
- [ ] Infinity Reserve passport/selfie pages

Legacy VCs remain `@available(*, deprecated)` until the above are done.

### FastTrack

- Presented over the FastTrack page by `ApplicationCapturePassportHostViewController` /
  `ApplicationCaptureSelfieHostViewController`; FTI keeps its existing-document preview, its review screen
  and its document-API upload, and receives the cropped image through `onCapturedImage`.
- Passport OCR still runs (`IDCVisaPassportVerifier`), so `ScanDocsCoordinator.storePassportData` — and with
  it the citizenship-mismatch interception — applies here too.

### Post-checkout

- `USLoginDetailsCoordinator` hosts a passport session whose pieces come from what is already uploaded, with
  per-piece `copy` overrides for the consular-login headings.
- Pending-doc re-upload routes only `passport` and `photo` through
  `ApplicationCaptureLauncher.presentPostCheckoutDocument` (image only — the host owns naming, storage and
  upload). Other document keys stay on `AVImageCaptureViewController`; PDF import moves to the top bar's
  file action.

### DocVault

- `ApplicationCaptureLauncher.presentDocVaultPassport` / `presentDocVaultSelfie` — cropped image only via `IDCPassThroughVerifier` (no OCR, no `UserData` writes).
- Optional PDF/file import on passport scanner uses `UIDocumentPicker` in `PassportScannerView` (unchanged product behavior).
