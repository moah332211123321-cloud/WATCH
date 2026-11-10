import SwiftUI
import WatchCore

/// Renders a background view at the watch's pixel size into RGB565 (big-endian, as the reference app).
/// The watch draws the time itself, so the rendered view must not contain a clock.
@MainActor
func renderFacePixels<V: View>(_ view: V, screen: ScreenInfo) -> Data? {
    let w = screen.width, h = screen.height
    let renderer = ImageRenderer(content: view.frame(width: CGFloat(w), height: CGFloat(h)))
    renderer.scale = 1
    guard let cg = renderer.cgImage else { return nil }
    var rgba = [UInt8](repeating: 0, count: w * h * 4)
    let ok: Bool = rgba.withUnsafeMutableBytes { raw in
        guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    return ok ? RGB565.encode(rgba: rgba, width: w, height: h) : nil
}

/// Preview frame with the watch's aspect ratio and shape; falls back to a square.
struct WatchShapeFrame<Content: View>: View {
    let screen: ScreenInfo?
    @ViewBuilder var content: Content

    var body: some View {
        let aspect = screen.map { CGFloat($0.width) / CGFloat(max($0.height, 1)) } ?? 1
        let round = screen?.isRound ?? false
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { content }   // overlay keeps the content inside the frame (fixes the overflow)
            .clipShape(round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: Tok.Radius.l, style: .continuous)))
            .overlay {
                (round ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: Tok.Radius.l, style: .continuous)))
                    .stroke(Tok.border)
            }
    }
}

/// "Install on watch (experimental)" with an explicit confirmation and real progress.
struct ExperimentalInstallSection<Background: View>: View {
    @Environment(DeviceController.self) private var device
    let background: Background
    let timeColor: Color
    @State private var confirm = false
    @State private var state: SendState = .idle
    @State private var progress: Double = 0

    var body: some View {
        Section {
            Button { confirm = true } label: {
                Label(L("Install on watch (experimental)"), systemImage: "applewatch.and.arrow.forward")
            }
            .disabled(!device.isConnected || state == .sending || device.screen == nil)
            if state == .sending { ProgressView(value: progress) }
            SendStatusView(state: state)
            if !device.isConnected {
                Text(L("Connect your watch to install.")).font(.footnote).foregroundStyle(Tok.textMuted)
            } else if device.screen == nil {
                UnsupportedNote(reason: L("Your watch did not report its screen size, so the picture can't be prepared."))
            }
        } footer: {
            Text(L("Experimental: the transfer steps come from studying the original app and have not been tried on a watch yet. The watch draws the time itself on top of the picture."))
        }
        .sheet(isPresented: $confirm) {
            ConfirmPhraseSheet(title: L("Install on watch (experimental)"),
                               message: L("This sends a new photo face to your watch. What the watch shows if the transfer stops half-way is not known yet. Firmware and settings are not touched."),
                               phrase: "TRY") { consent in
                Task { await install(consent) }
            }
        }
    }

    @MainActor private func install(_ consent: UserConsent) async {
        guard let screen = device.screen, let pixels = renderFacePixels(background, screen: screen) else {
            state = .failed(S("Could not prepare the image.")); return
        }
        let c = timeColor.rgbHex
        state = .sending
        progress = 0
        do {
            try await device.installPhotoFace(pixels: pixels, timeColor: [UInt8(c >> 16 & 0xFF), UInt8(c >> 8 & 0xFF), UInt8(c & 0xFF)],
                                              consent: consent) { p in Task { @MainActor in progress = p } }
            state = .sent
        } catch {
            state = .failed(describe(error))
        }
    }
}
