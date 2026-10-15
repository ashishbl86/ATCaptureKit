import SwiftUI
import UIKit

extension Color {
    /// 6-digit RGB or 8-digit RGBA hex (alpha last), with or without `#`. Falls back to black.
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var raw: UInt64 = 0
        guard Scanner(string: value).scanHexInt64(&raw), value.count == 6 || value.count == 8 else {
            self.init(red: 0, green: 0, blue: 0)
            return
        }
        let hasAlpha = value.count == 8
        let r = Double((raw >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = Double((raw >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = Double((raw >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? Double(raw & 0xFF) / 255 : 1
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
