import ATUIKit
import SwiftUI
import UIKit

struct IDCPassportFlipView: View {
    let image: UIImage
    var text: String = IDCStrings.Capture.flipToBackPage
    var detections: IDCFieldDetections? = nil
    var onFinished: () -> Void = {}

    @State private var angle: Double = 0
    @State private var started = false

    var body: some View {
        window
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .task { await run() }
    }

    private var window: some View {
        ZStack {
            frozenStill
                .opacity(angle < 90 ? 1 : 0)

            promptPanel
                .opacity(angle >= 90 ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pureBlack)
        .clipShape(
            RoundedRectangle(
                cornerRadius: IDCTheme.Layout.viewfinderCornerRadius,
                style: .continuous
            )
        )
    }

    private var frozenStill: some View {
        IDCPassportDetectionVisual(
            image: image,
            visibleCount: IDCPassportDetectionVisual.sections.count,
            detections: detections
        )
    }

    private var promptPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.2.squarepath")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
            Text(text)
                .typoGraphy(.H7InterMedium16)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func run() async {
        guard !started else { return }
        started = true
        try? await Task.sleep(nanoseconds: UInt64(IDCTheme.Animation.flipInitialBeat * 1_000_000_000))
        guard !Task.isCancelled else { return }
        IDCHaptics.iconPop()
        withAnimation(.easeInOut(duration: IDCTheme.Animation.flipDuration)) { angle = 180 }
        try? await Task.sleep(nanoseconds: UInt64(IDCTheme.Animation.flipLinger * 1_000_000_000))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}

#if DEBUG
#Preview("Passport flip") {
    IDCScanViewfinder(caption: IDCStrings.Eyebrow.backPage) {
        IDCPassportFlipView(image: IDCPreviewSupport.sampleImage(label: "Front Page"))
    }
    .frame(height: 380)
    .padding(20)
}
#endif
