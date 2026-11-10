import SwiftData
import SwiftUI
import WatchCore

/// 100 original watch-face backgrounds: 10 drawn styles × 10 palettes, all generated in code.
/// Style directions (AMOLED minimal, neon arcs, gradients, glass, geometry, nature) follow common trends
/// seen on Dribbble/Behance; no artwork from those sites is used. The watch draws the time on top.
enum FaceStyle: Int, CaseIterable, Identifiable {
    case aurora, neonArcs, ticks, glassOrbs, waves, geometric, dunes, dotGrid, arabesque, rings
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .aurora: return S("Aurora")
        case .neonArcs: return S("Neon arcs")
        case .ticks: return S("Minimal ticks")
        case .glassOrbs: return S("Glass orbs")
        case .waves: return S("Waves")
        case .geometric: return S("Geometric")
        case .dunes: return S("Dunes")
        case .dotGrid: return S("Dot grid")
        case .arabesque: return S("Arabesque")
        case .rings: return S("Rings")
        }
    }
}

struct FacePalette {
    let name: String
    let top: UInt32, bottom: UInt32, accent: UInt32, second: UInt32, time: UInt32
    var topColor: Color { Color(UIColor(rgb: top)) }
    var bottomColor: Color { Color(UIColor(rgb: bottom)) }
    var a: Color { Color(UIColor(rgb: accent)) }
    var b: Color { Color(UIColor(rgb: second)) }
    var timeColor: Color { Color(UIColor(rgb: time)) }

    static let all: [FacePalette] = [
        FacePalette(name: S("Midnight"), top: 0x05060A, bottom: 0x141A2E, accent: 0x3FD2C7, second: 0x7C5CFF, time: 0xFFFFFF),
        FacePalette(name: S("Sunset"), top: 0x1A0B12, bottom: 0x3D1426, accent: 0xFF7A59, second: 0xFFC15E, time: 0xFFF4E6),
        FacePalette(name: S("Forest"), top: 0x07130E, bottom: 0x10291D, accent: 0x4ADE80, second: 0xB6F09C, time: 0xEFFFF3),
        FacePalette(name: S("Ocean"), top: 0x03111F, bottom: 0x08304F, accent: 0x38BDF8, second: 0x22D3EE, time: 0xFFFFFF),
        FacePalette(name: S("Rose"), top: 0x1A0A14, bottom: 0x2E1022, accent: 0xFF6B9A, second: 0xFFB3C7, time: 0xFFF0F5),
        FacePalette(name: S("Gold"), top: 0x0B0906, bottom: 0x1F1A10, accent: 0xE6B455, second: 0xFFE3A3, time: 0xFFF7E0),
        FacePalette(name: S("Ice"), top: 0xE8F1F8, bottom: 0xC9DCEB, accent: 0x2563EB, second: 0x0EA5E9, time: 0x0B1A2A),
        FacePalette(name: S("Lava"), top: 0x120404, bottom: 0x2A0A06, accent: 0xFF3D2E, second: 0xFF9F1C, time: 0xFFFFFF),
        FacePalette(name: S("Lavender"), top: 0x120F1F, bottom: 0x221B3A, accent: 0xA48BFF, second: 0xF0ABFC, time: 0xF5F0FF),
        FacePalette(name: S("Mono"), top: 0x000000, bottom: 0x1C1C1F, accent: 0xFFFFFF, second: 0x8E8E98, time: 0xFFFFFF),
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

/// The background artwork (no clock).
struct DesignFaceView: View {
    let face: DesignFace

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let p = face.palette
            ZStack {
                LinearGradient(colors: [p.topColor, p.bottomColor], startPoint: .top, endPoint: .bottom)
                art(p, s).frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .clipped()
    }

    @ViewBuilder private func art(_ p: FacePalette, _ s: CGFloat) -> some View {
        switch face.style {
        case .aurora:
            ZStack {
                Ellipse().fill(p.a).frame(width: s * 0.95, height: s * 0.5).blur(radius: s * 0.14)
                    .offset(x: -s * 0.18, y: -s * 0.22).opacity(0.75)
                Ellipse().fill(p.b).frame(width: s * 0.8, height: s * 0.45).blur(radius: s * 0.16)
                    .offset(x: s * 0.2, y: s * 0.2).opacity(0.65)
            }
        case .neonArcs:
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .trim(from: 0.04 * Double(i), to: 0.55 + 0.12 * Double(i))
                        .stroke(AngularGradient(colors: [p.a, p.b, p.a], center: .center),
                                style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                        .rotationEffect(.degrees(Double(i) * 40 - 90))
                        .frame(width: s * (0.86 - 0.18 * Double(i)), height: s * (0.86 - 0.18 * Double(i)))
                        .shadow(color: p.a.opacity(0.8), radius: s * 0.03)
                }
            }
        case .ticks:
            ZStack {
                ForEach(0..<60, id: \.self) { i in
                    let major = i % 5 == 0
                    Capsule()
                        .fill(major ? p.a : p.b.opacity(0.55))
                        .frame(width: s * (major ? 0.014 : 0.006), height: s * (major ? 0.07 : 0.035))
                        .offset(y: -s * 0.43)
                        .rotationEffect(.degrees(Double(i) * 6))
                }
            }
        case .glassOrbs:
            ZStack {
                orb(p.a, s * 0.55).offset(x: -s * 0.18, y: -s * 0.16)
                orb(p.b, s * 0.42).offset(x: s * 0.22, y: s * 0.18)
                orb(p.a.opacity(0.6), s * 0.25).offset(x: s * 0.2, y: -s * 0.3)
            }
        case .waves:
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    Wave(phase: Double(i) * 0.9, amplitude: s * 0.05)
                        .stroke(i.isMultiple(of: 2) ? p.a : p.b, lineWidth: s * 0.012)
                        .opacity(1 - Double(i) * 0.12)
                        .offset(y: s * (-0.25 + 0.1 * Double(i)))
                }
            }
        case .geometric:
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: s * 0.05)
                        .stroke(i.isMultiple(of: 2) ? p.a : p.b, lineWidth: s * 0.01)
                        .frame(width: s * 0.55, height: s * 0.55)
                        .rotationEffect(.degrees(Double(i) * 15))
                        .opacity(0.85)
                }
            }
        case .dunes:
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    Hill(height: 0.35 + 0.12 * Double(i), shift: Double(i) * 0.23)
                        .fill(LinearGradient(colors: [p.a.opacity(0.9 - 0.18 * Double(i)), p.b.opacity(0.5)],
                                             startPoint: .top, endPoint: .bottom))
                }
            }
        case .dotGrid:
            Canvas { ctx, size in
                let n = 14
                let step = min(size.width, size.height) / CGFloat(n)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                var y = step / 2
                while y < size.height {
                    var x = step / 2
                    while x < size.width {
                        let d = hypot(x - center.x, y - center.y) / (min(size.width, size.height) / 2)
                        let r = step * 0.38 * max(0.15, 1 - d)
                        let color = d < 0.5 ? p.a : p.b
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(color.opacity(0.85)))
                        x += step
                    }
                    y += step
                }
            }
        case .arabesque:
            Canvas { ctx, size in
                let cell = min(size.width, size.height) / 4
                var y: CGFloat = 0
                var row = 0
                while y < size.height + cell {
                    var x: CGFloat = row.isMultiple(of: 2) ? 0 : cell / 2
                    while x < size.width + cell {
                        ctx.stroke(eightPointStar(center: CGPoint(x: x, y: y), radius: cell * 0.42),
                                   with: .color((row.isMultiple(of: 2) ? p.a : p.b).opacity(0.8)), lineWidth: cell * 0.04)
                        x += cell
                    }
                    y += cell * 0.87
                    row += 1
                }
            }
        case .rings:
            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    Circle().stroke(p.b.opacity(0.22), lineWidth: s * 0.006)
                        .frame(width: s * (0.92 - 0.12 * Double(i)), height: s * (0.92 - 0.12 * Double(i)))
                }
                Circle().trim(from: 0, to: 0.72)
                    .stroke(p.a, style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: s * 0.8, height: s * 0.8)
            }
        }
    }

    private func orb(_ color: Color, _ size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.9), color.opacity(0.15)], center: .topLeading,
                                 startRadius: 0, endRadius: size))
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: max(1, size * 0.02)))
            .frame(width: size, height: size)
    }
}

/// Two squares rotated 45° against each other.
private func eightPointStar(center: CGPoint, radius r: CGFloat) -> Path {
    var path = Path()
    for rotation in [0.0, Double.pi / 4] {
        let pts = (0..<4).map { k -> CGPoint in
            let a = rotation + Double(k) * .pi / 2 + .pi / 4
            return CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
        }
        path.addLines(pts)
        path.closeSubpath()
    }
    return path
}

struct Wave: Shape {
    var phase: Double
    var amplitude: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        p.move(to: CGPoint(x: rect.minX, y: midY))
        var x = rect.minX
        while x <= rect.maxX {
            let t = Double((x - rect.minX) / max(rect.width, 1)) * 2 * .pi * 1.5 + phase
            p.addLine(to: CGPoint(x: x, y: midY + amplitude * CGFloat(sin(t))))
            x += 2
        }
        return p
    }
}

struct Hill: Shape {
    var height: Double   // fraction of the rect covered from the bottom
    var shift: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = rect.maxY - rect.height * CGFloat(height)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: top + rect.height * 0.08))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: top),
                       control: CGPoint(x: rect.minX + rect.width * CGFloat(0.3 + shift.truncatingRemainder(dividingBy: 0.5)),
                                        y: top - rect.height * 0.18))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
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
                                    DesignFaceView(face: face)
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
                    DesignFaceView(face: face).overlay { SampleTime(color: face.palette.timeColor) }
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

    /// Stores a rendered copy so it can be renamed, favourited and edited like a photo face.
    @MainActor private func save() {
        let renderer = ImageRenderer(content: DesignFaceView(face: face).frame(width: 466, height: 466))
        renderer.scale = 1
        guard let data = renderer.uiImage?.pngData() else { return }
        context.insert(WatchFaceRecord(name: face.name, imageData: data, backgroundHex: Int(face.palette.top),
                                       textHex: Int(face.palette.time)))
        try? context.save()
        saved = true
    }
}
