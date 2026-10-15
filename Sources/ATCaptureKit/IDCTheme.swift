import ATUIKit
import SwiftUI

enum IDCTheme {

    enum Colors {
        static let screenBackground = Color(hex: "F9FAFB")
        static let cardBackground = Color(hex: "F4F5F6")

        static let statusCoachingForeground = Color(at: .accentAmber800)
        static let statusCoachingBackground = Color(at: .accentAmber100)
        static let statusReadyForeground = Color(at: .accentEmerald800)
        static let statusReadyBackground = Color(at: .accentEmerald100)
        static let statusAlertForeground = Color.pureWhite
        static let statusAlertBackground = Color.actionErrorRed500
        static let statusCapturingForeground = Color.pureBlack
        static let statusCapturingBackground = Color(hex: "9DD645")

        static let verifiedForeground = Color(hex: "116932")
        static let verifiedSpinnerDot = Color(hex: "16A34A")

        static let holdStillTint = Color(hex: "00FF26")

        static let failureWashStart = Color(hex: "F58F8F")
        static let failureWashEnd = Color(hex: "983D3D")
        static let failureWashOpacity: Double = 0.58

        static let failureDocumentAccent = Color.actionErrorRed500
        static let failureQualityAccent = Color(hex: "F0A114")

        static let primerAutoFillTint = Color(hex: "EFEBFB")
        static let primerErrorCheckTint = Color.accentEmerald50
        static let primerEncryptionTint = Color.accentSoftGold100
        static let primerCTAGradient: [Color] = [
            Color(hex: "E9E6F4"),
            Color(hex: "C7B3EE"),
            Color(hex: "EDA9A4"),
            Color(hex: "F0C68F"),
            Color(hex: "F5E7BD"),
        ]
    }

    enum Layout {
        static let screenHorizontalPadding: CGFloat = 20
        static let topBarTopPadding: CGFloat = 16
        static let scanTopBarControlSize: CGFloat = 48
        static let embeddedSheetTopBarTopPadding: CGFloat = 44
        static let headerTopPadding: CGFloat = 40
        static let headerAccessoryTopPadding: CGFloat = 20
        static let viewfinderTopPadding: CGFloat = 36
        static let bottomAreaTopPadding: CGFloat = 16
        static let bottomAreaBottomPadding: CGFloat = 8

        static let viewfinderCornerRadius: CGFloat = 40
        static let footerMinHeight: CGFloat = 130

        static let uploadSourceBadgeDiameter: CGFloat = 40
        static let uploadSourceIconSize: CGFloat = 18
        static let uploadSourceIconLabelSpacing: CGFloat = 15
        static let uploadSourceHorizontalPadding: CGFloat = 30
        static let uploadSourceRowVerticalPadding: CGFloat = 19.5
        static let uploadSourceRowLabelInset: CGFloat = 55
        static let uploadSourceTopPadding: CGFloat = 20
        static let uploadSourceBottomPadding: CGFloat = 30

        static let compactHeaderTopPadding: CGFloat = 16
        static let compactViewfinderTopPadding: CGFloat = 16
        static let compactFooterMinHeight: CGFloat = 84
        static let compactSelfieScannerTopPadding: CGFloat = 8

        static let previewImageCornerRadius: CGFloat = 8
        static let previewCardCornerRadius: CGFloat = 18
        static let previewCardPadding: CGFloat = 20

        static let passportBracketCornerRadius: CGFloat = 8
        static let passportBracketArmLength: CGFloat = 13
        static let passportBracketHorizontalPadding: CGFloat = 24

        static let statusPillVerticalPadding: CGFloat = 10
        static let statusPillHorizontalPadding: CGFloat = 20
        static let statusPillEdgeOverlap: CGFloat = 18
        static let scanSubStatusHeight: CGFloat = 44

        static let selfieRingPadding: CGFloat = 8.5
        static let selfieStatusPillBottomPadding: CGFloat = 18
        static let selfieCoachingPillBelowRingSpacing: CGFloat = 20
        static let selfieScannerTopPadding: CGFloat = 32

        static let reviewCardCornerRadius: CGFloat = 24
        static let reviewThumbnailCornerRadius: CGFloat = 10
        static let reviewHeaderTopPadding: CGFloat = 36

        static let reminderBellTopPadding: CGFloat = 64
        static let reminderActionsTopPadding: CGFloat = 72
        static let reminderConfirmedBottomPadding: CGFloat = 120
        static let reminderWheelHeight: CGFloat = 200
        static let reminderWheelVerticalPadding: CGFloat = 50
        static let reminderDayChipHeight: CGFloat = 70
        static let reminderDayChipInset: CGFloat = 5

        static let failureActionWidth: CGFloat = 220
    }

    enum Assets {
        static let passportDoc = "kyc_passport_doc"
    }

    enum Badge {
        static let inlineErrorCoinDiameter: CGFloat = 42
        static let inlineErrorMarkSize: CGFloat = 26
        static let reviewThumbnailCoinDiameter: CGFloat = 34
        static let reviewThumbnailMarkSize: CGFloat = 24
        static let reviewHeaderCoinDiameter: CGFloat = 64
        static let reviewHeaderIconSize: CGFloat = 28
        static let verifiedSpinnerSize: CGFloat = 44
        static let verifiedSealDiameter: CGFloat = 28
        static let failureCoinDiameter: CGFloat = 60
        static let failureCoinIconSize: CGFloat = 30
        static let connectionErrorCoinDiameter: CGFloat = 72
    }

    enum Sheet {
        static let darkBackdropOpacity: Double = 0.8
        static let cornerRadius: CGFloat = 28
    }

    enum Animation {
        static let selfieCompletionDuration: TimeInterval = 1.0
        static let selfieCompletionHold: TimeInterval = 1.05
        static let selfieCompletionReveal: TimeInterval = 0.3
        static let selfieCompletionFinishHold: TimeInterval = 1.0
        static let verifiedBeatNanoseconds: UInt64 = 900_000_000

        static let flipInitialBeat: TimeInterval = 0.35
        static let flipDuration: TimeInterval = 0.6
        static let flipLinger: TimeInterval = 2.1

        static let reminderLinkRevealNanoseconds: UInt64 = 10_000_000_000
        static let reminderConfirmDismissNanoseconds: UInt64 = 2_500_000_000

        static let gradientSubtitleReveal: TimeInterval = 0.9
        static let gradientSubtitleHoldNanoseconds: UInt64 = 1_600_000_000
        static let gradientSubtitleSettle: TimeInterval = 0.6
    }
}

extension LinearGradient {
    static let idcFailureWash = LinearGradient(
        colors: [IDCTheme.Colors.failureWashStart, IDCTheme.Colors.failureWashEnd],
        startPoint: .top,
        endPoint: .bottom
    )

    static let idcHoldStillWash = LinearGradient(
        colors: [
            IDCTheme.Colors.holdStillTint.opacity(0),
            IDCTheme.Colors.holdStillTint.opacity(0.2),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
