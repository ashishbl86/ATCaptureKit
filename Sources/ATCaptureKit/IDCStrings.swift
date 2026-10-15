import Foundation

enum IDCStrings {

    enum CTA {
        static let `continue` = "Continue"
        static let retry = "Retry"
        static let scanAgain = "Scan Again"
        static let reuploadFromDevice = "Re-upload from device"
        static let uploadFromDevice = "Upload from device"
        static let reupload = "Re-upload"
        static let scan = "Scan"
        static let giveAccess = "Give Access"
        static let or = "OR"
        static let skip = "Skip for now"
    }

    enum UploadSource {
        static let takePhoto = "Take a Photo"
        static let chooseFromGallery = "Choose from Gallery"
        static let chooseFile = "Choose a file"
    }

    enum Flow {
        static let defaultTitle = "Identity check"
    }

    enum Capture {
        static let scanPassport = "Scan your passport"
        static let flipToBackPage = "Now flip to the back page"
        static let captureWhenInFocus = "We'll auto capture it when passport is in focus"
        static let captureWhenInFocusHighlight = "auto capture it when passport is in focus"
        static let takeSelfie = "Take a selfie"
        static let selfieRequired = "Required by all governments"
        static let perfect = "Perfect"
    }

    enum Eyebrow {
        static let frontPage = "FRONT PAGE"
        static let backPage = "BACK PAGE"
    }

    enum PieceName {
        static let frontPage = "Front Page"
        static let backPage = "Back Page"
        static let selfie = "Selfie"
    }

    enum PassportGuidance {
        static let positionInGuides = "Position passport page inside the guiding lines"
        static let lightReflection = "Light reflection"
        static let lightReflectionTip = "Too bright - move away from direct light or tilt your phone"
        static let glareDetected = "Glare detected"
        static let glareDetectedTip = "Indirect light: Avoid scanning directly under overhead bulbs"
        static let fingersDetected = "Fingers detected"
        static let fingersDetectedTip = "Move your fingers off the passport details"
        static let notAPassport = "Not a passport"
        static let notAPassportTip = "This looks like a travel document — scan your passport"
        static let moveCloser = "Move closer"
        static let moveCloserTip = "Bring the passport nearer so it fills the guides"
        static let tooClose = "Too close"
        static let tooCloseTip = "Move the passport slightly further away"
        static let outOfGuides = "Out of frame"
        static let outOfGuidesTip = "Fit the whole passport page inside the guides"
        static let frontPageShown = "This is the front page"
        static let frontPageShownTip = "Flip to the last page of your passport"
        static let backPageShown = "This is the back page"
        static let backPageShownTip = "Flip to the photo page of your passport"
        static let capturing = "Capturing..."
    }

    enum SelfieGuidance {
        static let centerFace = "Center your face in the frame with good lighting"
        static let holdStill = "Hold still"
        static let lowLight = "Low light"
        static let lowLightTip = "Move to a brighter area or face a light source"
        static let tooBright = "Too bright"
        static let tooBrightTip = "Move away from direct light or face away from the window"
        static let removeGlasses = "Remove glasses"
        static let removeGlassesTip = "Take off your eyewear so your eyes are clearly visible"
        static let multipleFaces = "Multiple faces"
        static let multipleFacesTip = "Only you should be in the frame"
        static let notASelfie = "Not a selfie"
        static let notASelfieTip = "Upload a clear photo of your face, not a document"
        static let phoneNotStraight = "Hold phone straight"
        static let phoneNotStraightTip = "Hold your phone upright at eye level"
        static let phoneTilted = "Phone tilted"
        static let phoneTiltedTip = "Level your phone so it isn't leaning to one side"
        static let faceCovered = "Uncover your face"
        static let faceCoveredTip = "Remove anything covering your face"
        static let removeCap = "Remove cap"
        static let removeCapTip = "Take off any hat or head covering"
        static let eyesClosed = "Keep both eyes open"
        static let eyesClosedTip = "Look at the camera with both eyes open"
        static let closeMouth = "Close your mouth"
        static let closeMouthTip = "Keep your lips together so your teeth aren't visible"
        static let noSmile = "No smile please"
        static let noSmileTip = "Keep a neutral expression"
        static let tooClose = "Move back a little"
        static let tooCloseTip = "Hold your phone a bit further away"
        static let tooFar = "Come closer"
        static let tooFarTip = "Move your face closer so it fills the circle"
        static let notCentered = "Center your face"
        static let notCenteredTip = "Move your face into the middle of the circle"
        static let faceOutOfFrame = "Face out of frame"
        static let faceOutOfFrameTip = "Fit your whole face inside the circle"
        static let lookStraight = "Look straight ahead"
        static let lookStraightTip = "Face the camera directly without turning your head"
    }

    enum Footer {
        static let verifyingPassport = "Verifying passport"
        static let verified = "Verified"
        static let uploading = "Uploading"
        static let uploaded = "Uploaded"
    }

    enum Failure {
        static let passportChecksFailed = "Passport checks failed"
        static let visaPhotoChecksFailed = "Visa photo checks failed"

        static let documentCheckEyebrow = "Document check"
        static let qualityCheckEyebrow = "Quality check"
        static let invalidDocumentTitle = "Invalid document detected"
        static let invalidPassportMessage = "This image doesn't look like a valid passport page. Please upload a clear photo of your passport"
        static let invalidPassportBackMessage = "This image doesn't look like a valid passport back page. Please upload a clear photo of your passport"
        static let travelDocMessage = "This looks like a travel document, not a passport. Please upload a clear photo of your passport"
        static let textHardToReadTitle = "Text is hard to read"
        static let textHardToReadMessage = "Your passport details look out of focus. Hold your phone steady or ensure proper lighting so the text is sharp"
        static let lightReflectionTitle = "Light reflection on document"
        static let lightReflectionMessage = "Bright light is covering your passport details. Tilt your phone slightly or move away from direct light to clear it"
        static let fingersTitle = "Fingers covering the document"
        static let fingersMessage = "Move your fingers off the passport details and try again"
        static let connectionErrorTitle = "Connection error"
        static let checkFailedTitle = "Couldn't check your photo"
        static let scannerNotReadyMessage = "Couldn't get the scanner ready — please try again."
        static let unreadablePhotoMessage = "Couldn't read this photo — please try another."
        static let selfieCheckTitle = "Couldn't verify this selfie"
        static let notASelfieTitle = "This doesn't look like a selfie"
        static let notASelfieMessage = "Upload a clear photo of your face, not a document"
        static let selfieCheckMessage = "Please retake a clear, front-facing photo"
        static let scanLivePassport = "Scan live passport"
        static let takeLiveSelfie = "Take a live selfie"
        static let submitClearPassport = "Submit a clear photo of your passport"
        static let submitClearSelfie = "Submit a clear photo of yourself"

        static func defaultRejectionMessage(for piece: IDCPiece) -> String {
            piece.isPassport ? submitClearPassport : submitClearSelfie
        }
    }

    enum Review {
        static let errorHeadline = "Oops!\nWe found an error"
        static let allChecksPassed = "All checks passed"
        static let pieceLooksGood = "Everything looks great here"
    }

    enum Preview {
        static let reviewPhoto = "REVIEW PHOTO"
        static let passportFrontPage = "PASSPORT FRONT PAGE"
        static let passportBackPage = "PASSPORT BACK PAGE"
        static let yourSelfie = "YOUR SELFIE"

        static func sheetTitle(for piece: IDCPiece) -> String {
            switch piece {
            case .passportFront: return passportFrontPage
            case .passportBack: return passportBackPage
            case .selfie: return yourSelfie
            }
        }
    }

    enum Camera {
        static let permissionRequired = "Camera permission required"
        static let permissionRequiredTwoLines = "Camera permission\nrequired"
        static let restrictedTitle = "Camera access restricted"
        static let passportPermissionMessage = "To auto-scan your passport, please allow camera access in the prompt on the next screen"
        static let selfiePermissionMessage = "To auto-capture your selfie, please allow camera access in the prompt on the next screen"
        static let passportRestrictedMessage = "Camera use is blocked on this device (for example by parental controls or device management). Upload from your device below if available."
        static let selfieRestrictedMessage = "Camera use is blocked on this device (for example by parental controls or device management). Upload from your device below if available."

        static let primerWhyTitle = "Why we need camera access:"
        static let primerAutoFillTitle = "Instant Auto-Fill:"
        static let primerAutoFillMessage = "Auto-detects passport numbers, dates, and names so you skip manual typing entirely"
        static let primerErrorCheckTitle = "Instant Error-Checking:"
        static let primerErrorCheckMessage = "Ensures MRZ lines and expiration dates are read accurately without human typos"
        static let primerEncryptionTitle = "Bank-Grade Encryption:"
        static let primerEncryptionMessage = "Extracted data is instantly encrypted and locked inside your private DocVault"
    }

    enum Reminder {
        static let dontHaveItHandy = "Don\u{2019}t have it handy?"
        static let eyebrow = "Set reminder"
        static let sheetTitle = "Set a reminder to upload\nyour passport"
        static let remindTonight = "Remind me tonight"
        static let remindTomorrowMorning = "Remind me tomorrow morning"
        static let pickCustomTime = "Pick custom time"
        static let selectDateTime = "Select date & time"
        static let selectDateTimeMessage = "We\u{2019}ll notify and also send you a direct upload link to your email"
        static let setReminderCTA = "Set Reminder"
        static let confirmedTitle = "Reminder set!"
        static let confirmedTonight = "We\u{2019}ll ping you tonight and also send a direct upload link to your email"
        static let confirmedTomorrow = "We\u{2019}ll ping you tomorrow morning and also send a direct upload link to your email"
        static let confirmedNoNotificationAccess = "Notifications are off for Atlys — open the app when you\u{2019}re ready to upload your passport"

        static func confirmedCustom(_ formattedDate: String) -> String {
            "We\u{2019}ll ping you on \(formattedDate) and also send a direct upload link to your email"
        }

        static let notificationTitle = "Upload your passport"
        static let notificationBody = "Continue your identity check — scanning takes under a minute."
    }

    enum CoTraveller {
        static let message = "Upload a clear, front-facing photo from your gallery, or take a selfie if they\u{2019}re with you"
        static let uploadPhoto = "Upload Photo"
        static let captureLive = "Capture live"
        static let defaultFlowTitle = "Identity check"

        static func addPhotoTitle(name: String) -> String {
            "Add photo\nfor \(name)"
        }
    }

    enum Verifier {
        static let unreadablePassport = "We couldn't read your passport — submit a clear photo of your passport"
        static let offline = "We couldn't verify your passport due to a poor internet connection. Please check your network and try again."
        static let uploadFailed = "We couldn't upload your photo. Please check your connection and try again."
    }

    enum A11y {
        static let back = "Back"
        static let flipCamera = "Switch camera"
        static let rescan = "Re-scan"
        static let previewCapture = "Preview captured image"
        static let reminderHour = "Hour"
        static let reminderMinute = "Minute"
        static let reminderMeridiem = "AM or PM"
    }
}
