import ATUIKit
import SwiftUI

struct IDCCameraPrimerScreen: View {
    var message: String = IDCStrings.Camera.passportPermissionMessage
    let onContinue: () -> Void

    private struct Reason {
        let icon: Image
        let tint: Color
        let border: Color
        let title: String
        let message: String
    }

    private let reasons: [Reason] = [
        Reason(
            icon: ATIcon.SwiftUIImage.playlistAddCheck,
            tint: IDCTheme.Colors.primerAutoFillTint,
            border: Color.primaryBrandBlue100,
            title: IDCStrings.Camera.primerAutoFillTitle,
            message: IDCStrings.Camera.primerAutoFillMessage
        ),
        Reason(
            icon: ATIcon.SwiftUIImage.spellcheck,
            tint: IDCTheme.Colors.primerErrorCheckTint,
            border: Color.accentEmerald100,
            title: IDCStrings.Camera.primerErrorCheckTitle,
            message: IDCStrings.Camera.primerErrorCheckMessage
        ),
        Reason(
            icon: ATIcon.SwiftUIImage.verifiedUser,
            tint: IDCTheme.Colors.primerEncryptionTint,
            border: Color.accentSoftGold200,
            title: IDCStrings.Camera.primerEncryptionTitle,
            message: IDCStrings.Camera.primerEncryptionMessage
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    badge
                        .padding(.top, 48)

                    Text(IDCStrings.Camera.permissionRequiredTwoLines)
                        .typoGraphy(.H4InterMedium24)
                        .foregroundStyle(Color.pureBlack)
                        .padding(.top, 25)

                    Text(message)
                        .typoGraphy(.B1InterSemibold14)
                        .foregroundStyle(Color.pureBlack)
                        .padding(.top, 20)

                    IDCDashedSeparator()
                        .padding(.top, 50)

                    Text(IDCStrings.Camera.primerWhyTitle)
                        .typoGraphy(.T2InterBold12)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.pureBlack)
                        .padding(.top, 50)

                    reasonList
                        .padding(.top, 40)
                }
            }

            continueButton
                .padding(.top, 16)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(IDCTheme.Colors.screenBackground.ignoresSafeArea())
    }

    private var badge: some View {
        IDCScallopBadgeShape()
            .fill(Color.pureBlack)
            .frame(width: 60, height: 60)
            .overlay {
                IDCIcon(ATIcon.SwiftUIImage.cameraAlt, size: 24)
                    .foregroundStyle(Color.pureWhite)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.pureBlack)
                    .offset(x: 14, y: -8)
            }
    }

    private var reasonList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(reasons.enumerated()), id: \.offset) { index, reason in
                if index > 0 {
                    IDCDashedSeparator()
                        .padding(.leading, 70)
                        .padding(.vertical, 30)
                }
                HStack(alignment: .center, spacing: 20) {
                    Circle()
                        .fill(reason.tint)
                        .frame(width: 50, height: 50)
                        .overlay {
                            IDCIcon(reason.icon, size: 20)
                                .foregroundStyle(Color.pureBlack)
                        }
                        .overlay {
                            Circle()
                                .stroke(reason.border, lineWidth: 1)
                        }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(reason.title)
                            .typoGraphy(.B1InterSemibold14)
                            .foregroundStyle(Color.pureBlack)
                        Text(reason.message)
                            .typoGraphy(.B2InterSemibold12)
                            .foregroundStyle(Color.neutralGrey400)
                    }
                }
            }
        }
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(IDCStrings.CTA.continue)
                .typoGraphy(.B1InterSemibold14)
                .foregroundStyle(Color.pureBlack)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: IDCTheme.Colors.primerCTAGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .scaleEffect(1.4)
                    .blur(radius: 14)
                )
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        }
        .buttonStyle(.idcHaptic)
    }
}

struct IDCPermissionPromptSpotlight: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1.5)
                .frame(width: 342, height: 308)
                .offset(y: 12)

            IDCCurvedArrowShape()
                .stroke(Color.pureWhite, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(width: 110, height: 50)
                .offset(x: 108, y: 190)
        }
        .ignoresSafeArea()
    }
}

private struct IDCCurvedArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.35)
        let end = CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.30)
        let control = CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.35)
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)

        let tangent = atan2(end.y - control.y, end.x - control.x)
        let headLength = rect.height * 0.42
        for wing in [CGFloat.pi * 5 / 6, -CGFloat.pi * 5 / 6] {
            path.move(to: end)
            path.addLine(
                to: CGPoint(
                    x: end.x + cos(tangent + wing) * headLength,
                    y: end.y + sin(tangent + wing) * headLength
                )
            )
        }
        return path
    }
}

struct IDCDashedSeparator: View {
    var body: some View {
        IDCDashedLineShape()
            .stroke(Color.borderLightLight200, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(height: 1)
    }
}

private struct IDCDashedLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#if DEBUG
#Preview("Camera primer — passport") {
    IDCCameraPrimerScreen {}
}

#Preview("Camera primer — selfie") {
    IDCCameraPrimerScreen(message: IDCStrings.Camera.selfiePermissionMessage) {}
}

#Preview("Prompt spotlight") {
    IDCPermissionPromptSpotlight()
}
#endif
