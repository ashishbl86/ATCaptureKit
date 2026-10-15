import SwiftUI
import UIKit

enum IDCHaptics {

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    static func tap() {
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.7)
    }

    static func success() {
        notification.prepare()
        notification.notificationOccurred(.success)
    }

    static func error() {
        notification.prepare()
        notification.notificationOccurred(.error)
    }

    static func sheet() {
        softImpact.prepare()
        softImpact.impactOccurred(intensity: 0.8)
    }

    static func iconPop() {
        rigidImpact.prepare()
        rigidImpact.impactOccurred(intensity: 0.85)
    }

    static func tick() {
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.5)
    }

    static func thump() {
        heavyImpact.prepare()
        heavyImpact.impactOccurred(intensity: 1.0)
    }
}

struct IDCHapticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { IDCHaptics.tap() }
            }
    }
}

extension ButtonStyle where Self == IDCHapticButtonStyle {
    static var idcHaptic: IDCHapticButtonStyle { IDCHapticButtonStyle() }
}
