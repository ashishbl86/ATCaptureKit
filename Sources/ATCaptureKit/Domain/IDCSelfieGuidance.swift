enum IDCSelfieGuidance: String, Sendable {
    case autoCapturing = "Auto Capturing"
    case tooBright = "Too Bright"
    case tooDark = "Too Dark"
    case faceMissing = "Face Missing"
    case multipleFaces = "Multiple Faces"
    case notASelfie = "This doesn't look like a selfie"
    case holdStraight = "Position phone straight ahead at eye height."
    case tilted = "Phone tilted, please level it."
    case noTeeth = "Teeth Shouldn’t Be Visible"
    case smiling = "No Smile Please"
    case faceOutOfBounds = "Face out of frame"
    case specs = "Remove eyewear"
    case faceCovered = "Face covered"
    case headCovered = "Remove cap"
    case faceTooClose = "Face too close"
    case faceTooFar = "Come closer"
    case bothEyesClosed = "Both eyes closed"
    case oneEyeClosed = "One eye closed"
    case faceUp = "Head turned up — look straight"
    case faceDown = "Head turned down — look straight"
    case faceLeft = "Head turned left — look straight"
    case faceRight = "Head turned right — look straight"
    case faceNotCentered = "Face not centered"
    case goodPhoto = "Good photo, hold still"
}

extension IDCSelfieGuidance {
    var rank: Float {
        switch self {
        case .autoCapturing: 16
        case .tooBright: 15
        case .tooDark: 14
        case .faceMissing: 13
        case .notASelfie: 12.5
        case .multipleFaces: 12
        case .holdStraight: 11.7
        case .tilted: 11.6
        case .smiling, .noTeeth: 11.5
        case .faceOutOfBounds: 11
        case .specs: 10
        case .faceCovered: 9
        case .headCovered: 8
        case .bothEyesClosed: 7.1
        case .oneEyeClosed: 7
        case .faceTooClose: 6
        case .faceTooFar: 5
        case .faceUp, .faceDown: 4
        case .faceLeft, .faceRight: 3
        case .faceNotCentered: 2
        case .goodPhoto: 1
        }
    }
}
