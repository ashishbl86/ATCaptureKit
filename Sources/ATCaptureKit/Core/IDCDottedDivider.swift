import ATUIKit
import SwiftUI

struct IDCDottedDivider: View {
    var body: some View {
        IDCHorizontalDottedLine()
            .stroke(Color.neutralGrey300, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            .frame(height: 1)
    }
}

private struct IDCHorizontalDottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
