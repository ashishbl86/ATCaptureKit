import SwiftUI

/// Four rounded corner brackets (the guide arcs in design 890), drawn around the viewfinder's bounds.
struct IDCCornerBracketsShape: Shape {
    var cornerRadius: CGFloat = 20
    var armLength: CGFloat = 30

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let a = armLength

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + r + a))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + r + a, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - r - a, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r,
                    startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r + a))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - r - a))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - r - a, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + r + a, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r - a))

        return path
}
}
