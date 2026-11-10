import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WatchCore

/// S12: my faces (search, favourites, import, create).
struct FacesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchFaceRecord.createdAt, order: .reverse) private var faces: [WatchFaceRecord]
    @State private var search = ""
    @State private var onlyFavorites = false
    @State private var importing = false
    @State private var importError: String?

    private var shown: [WatchFaceRecord] {
        faces.filter { (!onlyFavorites || $0.isFavorite) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tok.Space.l) {
                    UnsupportedNote(reason: L("The original maker's face store is a private service, so Sawar uses your own photos and files."))
                    if shown.isEmpty {
                        ContentUnavailableView(L("No faces yet"), systemImage: "photo.on.rectangle",
                                               description: Text(L("Create one from a photo or import an image.")))
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Tok.Space.m)], spacing: Tok.Space.m) {
                        ForEach(shown) { face in
                            NavigationLink { FaceEditorView(face: face) } label: { FaceTile(face: face) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(face.isFavorite ? L("Remove from favourites") : L("Add to favourites")) {
                                        face.isFavorite.toggle(); try? context.save()
                                    }
                                    Button(L("Delete"), role: .destructive) { context.delete(face); try? context.save() }
                                }
                        }
                    }
                }
                .padding(Tok.Space.l)
            }
            .background(Tok.bg)
            .navigationTitle(L("Faces"))
            .searchable(text: $search, prompt: L("Search faces"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: $onlyFavorites) { Image(systemName: onlyFavorites ? "star.fill" : "star") }
                        .toggleStyle(.button)
                        .accessibilityLabel(Text(L("Favourites only")))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink { FaceEditorView(face: nil) } label: { Label(L("New from photo"), systemImage: "photo") }
                        Button { importing = true } label: { Label(L("Import image file"), systemImage: "square.and.arrow.down") }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text(L("Add face")))
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
                importFile(result)
            }
            .alert(L("Import failed"), isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button(L("OK")) {}
            } message: { Text(importError ?? "") }
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard UIImage(data: data) != nil else { importError = S("This file is not an image."); return }
            context.insert(WatchFaceRecord(name: url.deletingPathExtension().lastPathComponent, imageData: data))
            try context.save()
        } catch {
            importError = error.localizedDescription
        }
    }
}

struct FaceTile: View {
    let face: WatchFaceRecord
    var body: some View {
        VStack(alignment: .leading, spacing: Tok.Space.s) {
            FacePreview(face: face).frame(height: 150)
            HStack {
                Text(verbatim: face.name).font(.subheadline).lineLimit(1).foregroundStyle(Tok.text)
                if face.isFavorite { Image(systemName: "star.fill").foregroundStyle(Tok.warning).accessibilityHidden(true) }
            }
        }
    }
}

/// Round-cornered preview with time overlay (FacePreview).
struct FacePreview: View {
    let face: WatchFaceRecord
    var body: some View {
        ZStack {
            Color(UIColor(rgb: UInt32(face.backgroundHex)))
            if let image = UIImage(data: face.imageData) {
                Image(uiImage: image).resizable().scaledToFill()
            }
            VStack(spacing: 0) {
                Text(Date(), format: .dateTime.hour().minute())
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                if face.showDate {
                    Text(Date(), format: .dateTime.weekday().day()).font(.caption)
                }
            }
            .foregroundStyle(Color(UIColor(rgb: UInt32(face.textHex))))
            .shadow(radius: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tok.Radius.l, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Tok.Radius.l, style: .continuous).stroke(Tok.border))
        .accessibilityLabel(Text(verbatim: face.name))
    }
}

/// S13 + S14: edit, preview, install.
struct FaceEditorView: View {
    let face: WatchFaceRecord?
    @Environment(DeviceController.self) private var device
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pick: PhotosPickerItem?
    @State private var imageData = Data()
    @State private var background = Color.black
    @State private var textColor = Color.white
    @State private var showDate = true
    @State private var install: SendState = .idle

    var body: some View {
        Form {
            Section {
                FacePreview(face: draft).frame(height: 260)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                TextField(L("Name"), text: $name)
                PhotosPicker(selection: $pick, matching: .images) { Label(L("Choose photo"), systemImage: "photo") }
                ColorPicker(L("Background"), selection: $background, supportsOpacity: false)
                ColorPicker(L("Time colour"), selection: $textColor, supportsOpacity: false)
                Toggle(L("Show date"), isOn: $showDate)
            }
            Section {
                Button(L("Save")) { save() }.disabled(imageData.isEmpty || name.isEmpty)
                Button { Task { await installOnWatch() } } label: {
                    Label(L("Install on watch"), systemImage: "applewatch.and.arrow.forward")
                }
                .disabled(imageData.isEmpty || !device.isConnected || install == .sending)
                SendStatusView(state: install)
                if !device.isConnected {
                    Text(L("Connect your watch to install.")).font(.footnote).foregroundStyle(Tok.textMuted)
                }
            }
        }
        .navigationTitle(face == nil ? L("New face") : L("Edit face"))
        .onAppear(perform: load)
        .onChange(of: pick) { _, item in
            Task { if let data = try? await item?.loadTransferable(type: Data.self) { imageData = data } }
        }
    }

    /// Unsaved copy for the preview.
    private var draft: WatchFaceRecord {
        let d = WatchFaceRecord(name: name, imageData: imageData,
                                backgroundHex: background.rgbHex, textHex: textColor.rgbHex)
        d.showDate = showDate
        return d
    }

    private func load() {
        guard let face, imageData.isEmpty else { return }
        name = face.name; imageData = face.imageData; showDate = face.showDate
        background = Color(UIColor(rgb: UInt32(face.backgroundHex)))
        textColor = Color(UIColor(rgb: UInt32(face.textHex)))
    }

    private func save() {
        let target = face ?? {
            let f = WatchFaceRecord(name: name, imageData: imageData)
            context.insert(f)
            return f
        }()
        target.name = name; target.imageData = imageData; target.showDate = showDate
        target.backgroundHex = background.rgbHex; target.textHex = textColor.rgbHex
        try? context.save()
        dismiss()
    }

    private func installOnWatch() async {
        install = .sending
        let side = 240 // shortcut: real screen size comes from the screen-info reply once decoded
        guard let rgba = renderRGBA(side: side) else { install = .failed(S("Could not prepare the image.")); return }
        do {
            try await device.installFace(imageRGB565: RGB565.encode(rgba: rgba, width: side, height: side),
                                         width: side, height: side)
            install = .sent
        } catch {
            install = .failed(describe(error))
        }
    }

    /// Draws the preview into a square RGBA buffer.
    @MainActor private func renderRGBA(side: Int) -> [UInt8]? {
        let renderer = ImageRenderer(content: FacePreview(face: draft).frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        guard let cg = renderer.cgImage else { return nil }
        var buffer = [UInt8](repeating: 0, count: side * side * 4)
        let ok: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return ok ? buffer : nil
    }
}

extension Color {
    /// 0xRRGGBB of this colour (sRGB).
    var rgbHex: Int {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return c(r) << 16 | c(g) << 8 | c(b)
    }
}
