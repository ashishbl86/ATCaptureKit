import SwiftUI
import UIKit


/// The static green detection visual (design 991): the blurred/dimmed still + green tint + shimmering grid
/// + the detected-section boxes up to `visibleCount`. Pure rendering (no timers), so it's driven by the
/// animated overlay below AND shown fully-revealed as the flip's front face — giving a seamless hand-off
/// (the card flips FROM the same green overlay, no flash).
struct IDCPassportDetectionVisual: View {
    /// Which passport page the still shows — picks the callout set (front: passport
    /// no./signature/expiry/MRZ; back: parents name/address/file no.).
    enum Page { case front, back }

    let image: UIImage
    let visibleCount: Int
    var gridShown: Bool = true
    var page: Page = .front
    /// The scan's real field boxes (photo/signature/MRZ, normalized to `image`). When present, callouts pin
    /// to the model's detections (and derive Passport No./Expiry from real anchors); `nil` — or any missing
    /// box — falls back to the static Figma placement. Faithful port of Android's `placeScanFields`.
    /// Only meaningful for `.front`; the back page has no model-detected anchors and always places statically.
    var detections: IDCFieldDetections? = nil

    struct DetectionSection { let label: String; let rect: CGRect }

    /// Appearance order + STATIC-FALLBACK placement as fractions of the viewfinder, from Figma 991
    /// (card 380×313.7). Used only when the matching real box is absent.
    static let sections: [DetectionSection] = [
        .init(label: "Passport No.", rect: CGRect(x: 0.601, y: 0.277, width: 0.278, height: 0.094)),
        .init(label: "Signature",    rect: CGRect(x: 0.109, y: 0.529, width: 0.315, height: 0.106)),
        .init(label: "Expiry Date",  rect: CGRect(x: 0.601, y: 0.540, width: 0.253, height: 0.109)),
        .init(label: "MRZ",          rect: CGRect(x: 0.134, y: 0.741, width: 0.735, height: 0.106)),
    ]

    /// Back-page callouts (updated post-scan design): all static — no model anchors exist for these fields.
    static let backSections: [DetectionSection] = [
        .init(label: "Parents name", rect: CGRect(x: 0.128, y: 0.175, width: 0.276, height: 0.073)),
        .init(label: "Address",      rect: CGRect(x: 0.128, y: 0.437, width: 0.752, height: 0.148)),
        .init(label: "File no.",     rect: CGRect(x: 0.128, y: 0.777, width: 0.276, height: 0.073)),
    ]

    static func sections(for page: Page) -> [DetectionSection] {
        page == .back ? backSections : sections
    }

    static let green = Color(hex: "11FF00")
    /// Detected-pill wash (Figma 1327: rgba(0,100,67,0.35) — the backdrop blur is provided by the
    /// already-blurred still underneath).
    private static let pillFill = Color(hex: "006443").opacity(0.35)

    // Placement constants (match Android's PassportAnalysisOverlay; pill metrics from Figma 1327).
    private static let labelGap: CGFloat = 4
    private static let minBoxW: CGFloat = 56
    private static let minBoxH: CGFloat = 29.4
    private static let maxBoxH: CGFloat = 29.4
    private static let labelFont = UIFont(name: "Inter-SemiBold", size: 12) ?? .systemFont(ofSize: 12, weight: .semibold)

    /// A callout resolved to overlay coordinates — box and label placed independently (the label lands
    /// wherever it doesn't collide, mirroring Android's solver).
    private struct PlacedField { let label: String; let box: CGRect; let labelRect: CGRect }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let placed = placeScanFields(in: size)
            ZStack(alignment: .topLeading) {
                // Fit (not fill) so the whole passport is visible, letterboxed on the viewfinder's black —
                // matching the "Processing…" freeze. Bounded to the viewfinder so it never overflows.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .blur(radius: 5)

                Color.black.opacity(0.7)

                // Green tint, transparent at the top → green at the bottom (Figma: rgba(0,255,38,0→0.2)).
                LinearGradient(
                    colors: [Color(hex: "00FF26").opacity(0), Color(hex: "00FF26").opacity(0.2)],
                    startPoint: .top, endPoint: .bottom
                )

                IDCDetectionShimmerGrid(color: Self.green)
                    .opacity(gridShown ? 1 : 0)

                ForEach(Array(placed.enumerated()), id: \.offset) { index, field in
                    if index < visibleCount {
                        detection(field)
                            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .topLeading)))
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func detection(_ field: PlacedField) -> some View {
        // Draw box + label inside their shared bounding box (so the pop scales from the group's top-left,
        // matching the original static look), then place that group in the overlay.
        let bounds = field.box.union(field.labelRect)
        return ZStack(alignment: .topLeading) {
            Text(field.label)
                .font(.custom("Inter-SemiBold", size: 12))
                .tracking(-0.12)
                .foregroundStyle(Self.green)
                .fixedSize()
                .frame(width: field.labelRect.width, height: field.labelRect.height, alignment: .topLeading)
                .offset(x: field.labelRect.minX - bounds.minX, y: field.labelRect.minY - bounds.minY)

            ZStack {
                Rectangle().fill(Self.pillFill)
                IDCCornerBracketsShape(cornerRadius: 0, armLength: 4)
                    .stroke(Self.green, lineWidth: 0.75)
                Text("DETECTED")
                    .font(.custom("Inter-Bold", size: 12))
                    .tracking(0.96)
                    .foregroundStyle(Self.green)
                    // Never wrap to a second line — shrink to fit a narrow box instead.
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 4)
            }
            .frame(width: field.box.width, height: field.box.height)
            .offset(x: field.box.minX - bounds.minX, y: field.box.minY - bounds.minY)
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        .offset(x: bounds.minX, y: bounds.minY)
    }

    /// Resolve the four callouts to concrete overlay rects. Signature/MRZ pin to real boxes; Passport No.
    /// and Expiry (no model class) derive from real anchors (number tops the photo; expiry sits above the
    /// MRZ). Any missing box falls back to the static Figma fractions. Labels are then placed **above**
    /// their box (stacking higher to dodge obstacles/other labels), never beside or below it.
    private func placeScanFields(in size: CGSize) -> [PlacedField] {
        let areaW = size.width, areaH = size.height
        guard areaW > 0, areaH > 0 else { return [] }

        // Normalized-crop rect → overlay rect (the ContentScale.Fit letterbox mapping of the preview image).
        let imgAspect = image.size.height > 0 ? image.size.width / image.size.height : 1
        let fitsWidth = imgAspect >= areaW / areaH
        let drawnW = fitsWidth ? areaW : areaH * imgAspect
        let drawnH = fitsWidth ? areaW / imgAspect : areaH
        let offX = (areaW - drawnW) / 2
        let offY = (areaH - drawnH) / 2
        func onDocument(_ r: CGRect) -> CGRect {
            CGRect(x: offX + drawnW * r.minX, y: offY + drawnH * r.minY,
                   width: drawnW * r.width, height: drawnH * r.height)
        }
        // Clamp a box to a clean min/max size around its own centre so tiny/huge detections still read well.
        func readable(_ r: CGRect) -> CGRect {
            let w = max(r.width, Self.minBoxW)
            let h = min(max(r.height, Self.minBoxH), Self.maxBoxH)
            let l = min(max(r.midX - w / 2, 0), max(areaW - w, 0))
            let t = min(max(r.midY - h / 2, 0), max(areaH - h, 0))
            return CGRect(x: l, y: t, width: w, height: h)
        }
        // Static fallback: the original Figma fractions, treated as positions ON THE PASSPORT (they were
        // tuned against the card where the passport fills the frame). Routed through `onDocument` so a
        // fallback callout rides the letterboxed document exactly like a real detection — never the bare
        // viewfinder window — and through `readable` so it gets the same uniform pill height.
        func fallback(_ i: Int) -> CGRect {
            readable(onDocument(Self.sections[i].rect))
        }

        let boxes: [CGRect]
        if page == .back {
            // No model anchors on the back page — every callout uses its static placement.
            boxes = Self.backSections.map { onDocument($0.rect) }
        } else {
            let sign = detections?.signature.map { readable(onDocument($0)) }
            let mrz = detections?.mrz.map { readable(onDocument($0)) }

            // Passport No. row tops the photo, right-hand data column.
            let passportNo = detections?.photo.map { p -> CGRect in
                let top = min(p.minY + 0.02, 0.85)
                let bottom = min(p.minY + 0.11, 0.94)
                return readable(onDocument(CGRect(x: 0.58, y: top, width: 0.86 - 0.58, height: bottom - top)))
            }
            // Expiry hugs the right-hand data column, just above the MRZ block.
            var expiry = detections?.mrz.map { m -> CGRect in
                let bottom = max(m.minY - 0.03, 0.12)
                return readable(onDocument(CGRect(x: 0.60, y: bottom - 0.09, width: 0.84 - 0.60, height: 0.09)))
            }
            // The derived expiry box may move — nudge it off a real signature box if they collide.
            if let e = expiry, let s = sign, e.intersects(s) {
                let left = min(s.maxX + 6, max(areaW - e.width, 0))
                expiry = CGRect(x: left, y: e.minY, width: e.width, height: e.height)
            }

            boxes = [passportNo ?? fallback(0), sign ?? fallback(1), expiry ?? fallback(2), mrz ?? fallback(3)]
        }
        // Collision set = the drawn boxes (+ already-placed labels). The photo box isn't drawn, so it no
        // longer pushes labels around — each label just sits directly above its own box.
        let obstacles = boxes

        var placedLabels: [CGRect] = []
        func placeLabel(_ box: CGRect, _ labelSize: CGSize) -> CGRect {
            let lw = labelSize.width, lh = labelSize.height
            func fits(_ c: CGPoint) -> Bool {
                let r = CGRect(x: c.x, y: c.y, width: lw, height: lh)
                return r.minX >= 0 && r.minY >= 0 && r.maxX <= areaW && r.maxY <= areaH &&
                    !obstacles.contains(where: { $0.intersects(r) }) &&
                    !placedLabels.contains(where: { $0.intersects(r) })
            }
            // Labels ALWAYS sit above their box — never beside or below it. Prefer left-aligned, then
            // centred; if both collide, step further up (stacking clear of the box / other labels) so it
            // still reads above. Final fallback: above-left, clamped on-screen.
            var candidates = [
                CGPoint(x: box.minX, y: box.minY - Self.labelGap - lh),         // above, left-aligned
                CGPoint(x: box.midX - lw / 2, y: box.minY - Self.labelGap - lh), // above, centred
            ]
            let clampedX = min(max(box.minX, 0), max(areaW - lw, 0))
            var y = box.minY - Self.labelGap - lh - (lh + Self.labelGap) // one step above the base row
            while y >= 0 {
                candidates.append(CGPoint(x: clampedX, y: y))
                y -= (lh + Self.labelGap)
            }
            let origin = candidates.first(where: fits)
                ?? CGPoint(x: clampedX, y: max(box.minY - Self.labelGap - lh, 0))
            let rect = CGRect(x: origin.x, y: origin.y, width: lw, height: lh)
            placedLabels.append(rect)
            return rect
        }

        return boxes.enumerated().map { i, box in
            let label = Self.sections(for: page)[i].label
            let labelSize = (label as NSString).size(withAttributes: [.font: Self.labelFont])
            return PlacedField(label: label, box: box, labelRect: placeLabel(box, labelSize))
        }
    }
}

/// Plays the detection animation (design 991) over the frozen FRONT still while it uploads: the grid fades
/// in, then the detected sections pop in one-by-one, each with an icon-pop haptic. Fixed timeline to
/// completion — it does NOT cut short on the upload response — then calls `onFinished`. Its end state (all
/// sections shown) is the exact visual the flip uses as its front face, so the hand-off is seamless.
struct IDCPassportDetectionOverlay: View {
    let image: UIImage
    /// Real field boxes for this scan (nil → static placements). Forwarded to the visual.
    var detections: IDCFieldDetections? = nil
    var page: IDCPassportDetectionVisual.Page = .front
    var onFinished: () -> Void = {}

    @State private var visibleCount = 0
    @State private var gridShown = false
    @State private var started = false

    var body: some View {
        IDCPassportDetectionVisual(image: image, visibleCount: visibleCount, gridShown: gridShown, page: page, detections: detections)
            .onAppear(perform: start)
    }

    private func start() {
        guard !started else { return }
        started = true
        withAnimation(.easeOut(duration: 0.4)) { gridShown = true }

        let sectionCount = IDCPassportDetectionVisual.sections(for: page).count
        let firstDelay = 0.5, gap = 0.5
        for index in 0..<sectionCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + firstDelay + Double(index) * gap) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { visibleCount = index + 1 }
                IDCHaptics.iconPop()
            }
        }
        // Hold briefly after the last label so it doesn't cut abruptly, then hand back to the flow.
        let total = firstDelay + Double(sectionCount) * gap + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + total, execute: onFinished)
    }
}

/// The shimmering green gridlines behind the detection labels (design 991). Each line pulses on its own
/// phase so the grid fades in/out at scattered places rather than all together.
private struct IDCDetectionShimmerGrid: View {
    let color: Color
    var columns = 9
    var rows = 7

    var body: some View {
        // Qualify: the app defines its own `TimelineView` (Doxie) in this module, which would shadow this.
        SwiftUI.TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let cw = size.width / CGFloat(columns)
                let ch = size.height / CGFloat(rows)
                for i in 0...columns {
                    let x = CGFloat(i) * cw
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(color.opacity(opacity(seed: i, t: t))), lineWidth: 0.75)
                }
                for j in 0...rows {
                    let y = CGFloat(j) * ch
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(color.opacity(opacity(seed: j + 100, t: t))), lineWidth: 0.75)
                }
            }
        }
    }

    /// Scattered per-line phase (deterministic, no overflow) so lines don't pulse in unison.
    private func opacity(seed: Int, t: Double) -> Double {
        let phase = (Double(seed) * 1.7).truncatingRemainder(dividingBy: .pi * 2)
        return 0.10 + 0.30 * (0.5 + 0.5 * sin(t * 1.6 + phase))
    }
}
