import SwiftData
import SwiftUI
import WatchCore

/// 100 original watch-face backgrounds: 10 drawn styles × 10 palettes, all generated in code.
/// Direction: flat bold colour, Bauhaus geometry, dot matrix, pie dials, bento tiles — modern
/// trends seen on Dribbble/Behance and in the user's references. No artwork is copied.
/// The watch draws the time on top of a still picture; the animation is for the in-app preview only.
enum FaceStyle: Int, CaseIterable, Identifiable {
    case bauhaus, dotMatrix, pies, bento, arrows, ruler, pixels, burst, blobs, squircles
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .bauhaus: return S("Bauhaus")
        case .dotMatrix: return S("Dot matrix")
        case .pies: return S("Pie dials")
        case .bento: return S("Bento tiles")
        case .arrows: return S("Arrows")
        case .ruler: return S("Ruler")
        case .pixels: return S("Pixels")
        case .burst: return S("Sunburst")
        case .blobs: return S("Soft blobs")
        case .squircles: return S("Squircles")
        }
    }
}

struct FacePalette {
    let name: String
    let bg: UInt32, ink: UInt32, accent: UInt32, soft: UInt32, time: UInt32
    var bgColor: Color { Color(UIColor(rgb: bg)) }
    var inkColor: Color { Color(UIColor(rgb: ink)) }
    var accentColor: Color { Color(UIColor(rgb: accent)) }
    var softColor: Color { Color(UIColor(rgb: soft)) }
    var timeColor: Color { Color(UIColor(rgb: time)) }

    static let all: [FacePalette] = [
        FacePalette(name: S("Signal"), bg: 0x0B0B0C, ink: 0xEDEDED, accent: 0xFF4F12, soft: 0x3A3A3D, time: 0xFFFFFF),
        FacePalette(name: S("Paper"), bg: 0xECEAE4, ink: 0x111111, accent: 0xFF4F12, soft: 0xBDBAB2, time: 0x111111),
        FacePalette(name: S("Electric"), bg: 0x0A0F2C, ink: 0xFFFFFF, accent: 0x2F6BFF, soft: 0x1E2A5A, time: 0xFFFFFF),
        FacePalette(name: S("Lime"), bg: 0x101010, ink: 0xF2F2F2, accent: 0xC6F432, soft: 0x2E2E2E, time: 0xFFFFFF),
        FacePalette(name: S("Lilac"), bg: 0xF6D6F0, ink: 0x1A1A1A, accent: 0x9B5CFF, soft: 0xE7A8DC, time: 0x1A1A1A),
        FacePalette(name: S("Sunflower"), bg: 0xFFD60A, ink: 0x111111, accent: 0xFF4F12, soft: 0xF2B705, time: 0x111111),
        FacePalette(name: S("Mint"), bg: 0x0E1F19, ink: 0xE8FFF4, accent: 0x3DDC97, soft: 0x1F3D32, time: 0xFFFFFF),
        FacePalette(name: S("Slate"), bg: 0x3E4550, ink: 0xF1F1F1, accent: 0xFF4F12, soft: 0x5A626E, time: 0xFFFFFF),
        FacePalette(name: S("Cherry"), bg: 0x1A0507, ink: 0xFFE9E9, accent: 0xFF3B30, soft: 0x4A1418, time: 0xFFFFFF),
        FacePalette(name: S("Sky"), bg: 0x64C8FF, ink: 0x0B1A2A, accent: 0xFFFFFF, soft: 0x9ADBFF, time: 0x0B1A2A),
    ]
}

struct DesignFace: Identifiable, Hashable {
    let id: Int          // 1…100
    let style: FaceStyle
    let paletteIndex: Int
    var palette: FacePalette { FacePalette.all[paletteIndex] }
    var name: String { "\(style.title) · \(palette.name)" }

    static let all: [DesignFace] = (0..<100).map {
        DesignFace(id: $0 + 1, style: FaceStyle(rawValue: $0 / 10)!, paletteIndex: $0 % 10)
    }
}

/// The background artwork (no clock). `t` = seconds for the preview animation; 0 = the still sent to the watch.
struct DesignFaceView: View {
    let face: DesignFace
    var t: Double = 0
    var body: some View {
        Canvas { ctx, size in FaceArt.draw(face, in: &ctx, size: size, t: t) }
    }
}

/// Live, animated preview (in the app only).
struct AnimatedDesignFace: View {
    let face: DesignFace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            DesignFaceView(face: face)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                DesignFaceView(face: face, t: tl.date.timeIntervalSinceReferenceDate)
            }
        }
    }
}

enum FaceArt {
    static func draw(_ f: DesignFace, in ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let p = f.palette
        let w = size.width, h = size.height, s = min(w, h)
        let ink = GraphicsContext.Shading.color(p.inkColor)
        let accent = GraphicsContext.Shading.color(p.accentColor)
        let soft = GraphicsContext.Shading.color(p.softColor)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(p.bgColor))
        var rng = Seeded(f.id)

        switch f.style {
        case .bauhaus:
            let bob = CGFloat(sin(t * 1.3)) * s * 0.02
            ctx.fill(circle(CGPoint(x: w * 0.3, y: h * 0.3 + bob), s * 0.2), with: accent)
            var half = Path()
            half.addArc(center: CGPoint(x: w * 0.28, y: h * 0.86), radius: s * 0.24,
                        startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            half.closeSubpath()
            ctx.fill(half, with: ink)
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.58, y: h * 0.1, width: s * 0.3, height: s * 0.3),
                          cornerRadius: s * 0.04), with: soft)
            var quarter = Path()
            quarter.move(to: CGPoint(x: w * 0.92, y: h * 0.62))
            quarter.addArc(center: CGPoint(x: w * 0.92, y: h * 0.62), radius: s * 0.26,
                           startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            quarter.closeSubpath()
            ctx.fill(quarter, with: accent)
            for i in 0..<4 { for j in 0..<4 {
                ctx.fill(circle(CGPoint(x: w * 0.62 + CGFloat(i) * s * 0.07, y: h * 0.74 + CGFloat(j) * s * 0.06), s * 0.012),
                         with: ink)
            } }

        case .dotMatrix:
            let cols = 4, rows = 5
            let cell = min(w / CGFloat(cols), h / CGFloat(rows))
            let ox = (w - cell * CGFloat(cols)) / 2, oy = (h - cell * CGFloat(rows)) / 2
            let lit = (Int(t * 1.5) + f.id) % (cols * rows)
            for r in 0..<rows { for c in 0..<cols {
                let k = r * cols + c
                let center = CGPoint(x: ox + cell * (CGFloat(c) + 0.5), y: oy + cell * (CGFloat(r) + 0.5))
                let on = k == lit || k == (lit + 7) % (cols * rows)
                ctx.fill(circle(center, cell * 0.44), with: on ? accent : soft)
            } }

        case .pies:
            for k in 0..<4 {
                let cx = w * (k % 2 == 0 ? 0.28 : 0.72), cy = h * (k < 2 ? 0.3 : 0.7)
                let r = s * 0.2
                ctx.fill(circle(CGPoint(x: cx, y: cy), r), with: k == 0 ? soft : ink)
                let sweep = 60 + Double(k) * 70 + (t * 20).truncatingRemainder(dividingBy: 360)
                var wedge = Path()
                wedge.move(to: CGPoint(x: cx, y: cy))
                wedge.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .degrees(-90),
                             endAngle: .degrees(-90 + sweep), clockwise: false)
                wedge.closeSubpath()
                ctx.fill(wedge, with: k == 0 ? accent : .color(p.accentColor.opacity(0.85)))
            }

        case .bento:
            let g = s * 0.04
            let tiles: [(CGRect, GraphicsContext.Shading)] = [
                (CGRect(x: g, y: g, width: w - 2 * g, height: h * 0.42), accent),
                (CGRect(x: g, y: h * 0.42 + 2 * g, width: (w - 3 * g) / 2, height: h * 0.25), soft),
                (CGRect(x: w / 2 + g / 2, y: h * 0.42 + 2 * g, width: (w - 3 * g) / 2, height: h * 0.25), ink),
                (CGRect(x: g, y: h * 0.67 + 3 * g, width: w - 2 * g, height: h * 0.33 - 4 * g), soft),
            ]
            for (i, tile) in tiles.enumerated() {
                var c = ctx
                c.opacity = 0.85 + 0.15 * sin(t * 1.2 + Double(i))
                c.fill(Path(roundedRect: tile.0, cornerRadius: s * 0.07), with: tile.1)
            }
            ctx.fill(circle(CGPoint(x: w * 0.25, y: h * 0.545), s * 0.06), with: accent)
            ctx.stroke(circle(CGPoint(x: w * 0.75, y: h * 0.545), s * 0.06), with: accent, lineWidth: s * 0.02)

        case .arrows:
            for k in 0..<3 {
                let center = CGPoint(x: w * [0.3, 0.72, 0.4][k], y: h * [0.28, 0.5, 0.78][k])
                let r = s * [0.17, 0.14, 0.13][k]
                ctx.fill(circle(center, r), with: k == 1 ? accent : soft)
                var c = ctx
                c.translateBy(x: center.x, y: center.y)
                c.rotate(by: .degrees(Double(k) * 90 + sin(t + Double(k)) * 20 - 45))
                var arrow = Path()
                arrow.move(to: CGPoint(x: -r * 0.45, y: 0)); arrow.addLine(to: CGPoint(x: r * 0.45, y: 0))
                arrow.move(to: CGPoint(x: r * 0.15, y: -r * 0.3)); arrow.addLine(to: CGPoint(x: r * 0.45, y: 0))
                arrow.addLine(to: CGPoint(x: r * 0.15, y: r * 0.3))
                c.stroke(arrow, with: k == 1 ? ink : accent, style: StrokeStyle(lineWidth: r * 0.14, lineCap: .round, lineJoin: .round))
            }

        case .ruler:
            let band = CGRect(x: s * 0.06, y: h * 0.6, width: w - s * 0.12, height: h * 0.22)
            ctx.fill(Path(roundedRect: band, cornerRadius: s * 0.05), with: accent)
            let step = s * 0.025
            let shift = CGFloat((t * 12).truncatingRemainder(dividingBy: Double(step * 10)))
            var x = band.minX + s * 0.03 - shift
            var i = 0
            while x < band.maxX - s * 0.03 {
                if x > band.minX + s * 0.03 {
                    let tall = i % 10 == 0
                    let rect = CGRect(x: x, y: band.midY - (tall ? s * 0.05 : s * 0.025), width: s * 0.006,
                                      height: tall ? s * 0.1 : s * 0.05)
                    ctx.fill(Path(rect), with: ink)
                }
                x += step; i += 1
            }
            ctx.fill(Path(roundedRect: CGRect(x: band.minX + band.width * 0.18, y: band.midY - s * 0.01,
                                              width: band.width * 0.3, height: s * 0.02), cornerRadius: s * 0.01), with: ink)

        case .pixels:
            let n = 10
            let cell = s / CGFloat(n)
            let ox = (w - cell * CGFloat(n)) / 2, oy = (h - cell * CGFloat(n)) / 2
            for r in 0..<n { for c in 0..<n {
                let v = rng.next()
                guard v > 0.45 else { continue }
                let twinkle = sin(t * 2 + Double(r * n + c)) > 0.6
                let shade: GraphicsContext.Shading = v > 0.9 || twinkle ? accent : (v > 0.7 ? ink : soft)
                ctx.fill(Path(CGRect(x: ox + CGFloat(c) * cell + 1, y: oy + CGFloat(r) * cell + 1,
                                     width: cell - 2, height: cell - 2)), with: shade)
            } }

        case .burst:
            let c = CGPoint(x: w / 2, y: h / 2)
            let sweep = (t * 40).truncatingRemainder(dividingBy: 360)
            for k in 0..<60 {
                let a = Double(k) * 6
                let near = abs(((a - sweep + 540).truncatingRemainder(dividingBy: 360)) - 180) > 165
                let major = k % 5 == 0
                let r0 = s * (major ? 0.32 : 0.38), r1 = s * 0.46
                var line = Path()
                let rad = (a - 90) * .pi / 180
                line.move(to: CGPoint(x: c.x + r0 * CGFloat(cos(rad)), y: c.y + r0 * CGFloat(sin(rad))))
                line.addLine(to: CGPoint(x: c.x + r1 * CGFloat(cos(rad)), y: c.y + r1 * CGFloat(sin(rad))))
                ctx.stroke(line, with: near || major ? accent : soft, style: StrokeStyle(lineWidth: s * (major ? 0.02 : 0.008), lineCap: .round))
            }

        case .blobs:
            var c = ctx
            c.addFilter(.blur(radius: s * 0.12))
            for k in 0..<3 {
                let dx = CGFloat(sin(t * 0.5 + Double(k) * 2)) * s * 0.08
                let dy = CGFloat(cos(t * 0.4 + Double(k))) * s * 0.06
                let center = CGPoint(x: w * [0.3, 0.7, 0.5][k] + dx, y: h * [0.3, 0.45, 0.75][k] + dy)
                c.fill(circle(center, s * [0.3, 0.26, 0.22][k]), with: [accent, soft, ink][k])
            }

        case .squircles:
            let c = CGPoint(x: w / 2, y: h / 2)
            for k in 0..<6 {
                let side = s * (0.9 - 0.14 * CGFloat(k))
                var cc = ctx
                cc.translateBy(x: c.x, y: c.y)
                cc.rotate(by: .degrees(sin(t * 0.6 + Double(k) * 0.5) * 6 * Double(k)))
                let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
                cc.stroke(Path(roundedRect: rect, cornerRadius: side * 0.28, style: .continuous),
                          with: k == 2 ? accent : (k.isMultiple(of: 2) ? ink : soft), lineWidth: s * (k == 2 ? 0.03 : 0.012))
            }
        }
    }

    private static func circle(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}

/// Tiny deterministic generator so each face always looks the same.
struct Seeded {
    private var state: UInt64
    init(_ seed: Int) { state = UInt64(truncatingIfNeeded: seed) &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

/// Gallery of the 100 designs, filterable by style.
struct DesignGalleryView: View {
    @Environment(DeviceController.self) private var device
    @State private var style: FaceStyle?

    private var shown: [DesignFace] { DesignFace.all.filter { style == nil || $0.style == style } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tok.Space.m) {
                Text(L("Animated here in the app. On the watch the picture is still and the watch draws the time on top."))
                    .font(.footnote).foregroundStyle(Tok.textMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip(L("All"), selected: style == nil) { style = nil }
                        ForEach(FaceStyle.allCases) { s in
                            chip(LocalizedStringKey(s.title), selected: style == s) { style = s }
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Tok.Space.m)], spacing: Tok.Space.m) {
                    ForEach(shown) { face in
                        NavigationLink { DesignFaceDetailView(face: face) } label: {
                            VStack(spacing: Tok.Space.xs) {
                                WatchShapeFrame(screen: device.screen) {
                                    AnimatedDesignFace(face: face)
                                        .overlay { SampleTime(color: face.palette.timeColor, showDate: false).scaleEffect(0.6) }
                                }
                                Text(verbatim: "#\(face.id)").font(.caption2).foregroundStyle(Tok.textMuted)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: face.name))
                    }
                }
            }
            .padding(Tok.Space.l)
        }
        .background(Tok.bg)
        .navigationTitle(L("Design gallery"))
    }

    private func chip(_ title: LocalizedStringKey, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline)
                .padding(.horizontal, Tok.Space.m).padding(.vertical, Tok.Space.s)
                .background(selected ? Tok.accent : Tok.surface, in: Capsule())
                .foregroundStyle(selected ? Tok.onAccent : Tok.text)
        }
        .buttonStyle(.plain)
    }
}

struct DesignFaceDetailView: View {
    let face: DesignFace
    @Environment(DeviceController.self) private var device
    @Environment(\.modelContext) private var context
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                WatchShapeFrame(screen: device.screen) {
                    AnimatedDesignFace(face: face).overlay { SampleTime(color: face.palette.timeColor) }
                }
                .frame(maxWidth: 260)
                .frame(maxWidth: .infinity)
                Text(verbatim: face.name).font(.headline)
            }
            Section {
                Button(saved ? L("Saved to my faces") : L("Save to my faces")) { save() }.disabled(saved)
            }
            ExperimentalInstallSection(background: DesignFaceView(face: face), timeColor: face.palette.timeColor)
        }
        .navigationTitle(Text(verbatim: "#\(face.id)"))
    }

    /// Stores a rendered still so it can be renamed, favourited and edited like a photo face.
    @MainActor private func save() {
        let renderer = ImageRenderer(content: DesignFaceView(face: face).frame(width: 466, height: 466))
        renderer.scale = 1
        guard let data = renderer.uiImage?.pngData() else { return }
        context.insert(WatchFaceRecord(name: face.name, imageData: data, backgroundHex: Int(face.palette.bg),
                                       textHex: Int(face.palette.time)))
        try? context.save()
        saved = true
    }
}
