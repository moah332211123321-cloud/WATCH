import Foundation

/// Driver for the shared AB/EA protocol used by every family. Family-specific transfers go to `plugin`.
public actor WakeupDriver: WatchDriver {
    public private(set) var family: DeviceFamily
    public private(set) var capabilities = Capabilities()
    public private(set) var deviceInfo: DeviceInfo?
    public private(set) var platform: PlatformInfo?
    public private(set) var screen: ScreenInfo?
    public nonisolated let events: AsyncStream<WatchEvent>

    private let transport: WatchTransport
    private var plugin: FamilyPlugin
    private var decoder: WatchDecoder
    private var reassembler = Reassembler()
    private let continuation: AsyncStream<WatchEvent>.Continuation
    private var waiters: [UUID: (predicate: @Sendable (WatchEvent) -> Bool, cont: CheckedContinuation<WatchEvent, Error>)] = [:]
    private var lastEventAt = Date.distantPast
    private var syncBuffer: [WatchEvent]?
    /// Called for every frame in/out, for the debug packet log.
    private let log: (@Sendable (_ outgoing: Bool, _ bytes: [UInt8]) -> Void)?

    public init(transport: WatchTransport, family: DeviceFamily, timeZone: TimeZone = .current,
                log: (@Sendable (Bool, [UInt8]) -> Void)? = nil) {
        self.transport = transport
        self.family = family
        self.plugin = DriverFactory.plugin(for: family)
        self.decoder = WatchDecoder(timeZone: timeZone)
        self.log = log
        var c: AsyncStream<WatchEvent>.Continuation!
        self.events = AsyncStream { c = $0 }
        self.continuation = c
    }

    // MARK: sending

    public func perform(_ command: Command, consent: UserConsent? = nil) async throws {
        if command.isDestructive && consent == nil { throw WatchError.consentRequired }
        try await write(command.frame)
    }

    func write(_ frame: Frame, channel: Channel = .command) async throws {
        try await writeRaw(frame.bytes, pieceSize: max(20, transport.maximumWriteLength), channel: channel)
    }

    /// Writes bytes as-is in pieces of `pieceSize` (logged once as a whole).
    func writeRaw(_ bytes: [UInt8], pieceSize size: Int, channel: Channel = .command) async throws {
        log?(true, bytes)
        var offset = 0
        while offset < bytes.count {
            let end = min(offset + size, bytes.count)
            try await transport.write(Data(bytes[offset..<end]), channel: channel)
            offset = end
        }
    }

    // MARK: receiving

    public func receive(_ data: Data, channel: Channel) async {
        guard channel == .command else { return } // file-channel replies: not decoded yet
        let bytes = [UInt8](data)
        // Like the reference app (WatchNotify): only AB/EA notifications are reassembled; others go through as-is.
        if !reassembler.isPending, let first = bytes.first, FrameKind(rawValue: first) == nil {
            log?(false, bytes)
            await handle(decoder.decodeRaw(bytes))
            return
        }
        for frame in reassembler.feed(bytes) {
            log?(false, frame.bytes)
            await handle(decoder.decode(frame))
        }
    }

    private func handle(_ event: WatchEvent) async {
            lastEventAt = Date()
            if case .heartbeat = event { try? await write(Command.heartbeatReply.frame) }
            switch event {
            case let .deviceInfo(info):
                deviceInfo = info
                capabilities = info.capabilities
                if screen == nil { screen = info.tableScreen }
            case let .platform(p): platform = p
            case let .screen(s): screen = s
            default: break
            }
            syncBuffer?.append(event)
            continuation.yield(event)
            for (id, w) in waiters where w.predicate(event) {
                waiters[id] = nil
                w.cont.resume(returning: event)
            }
    }

    /// Writes `command` and waits for the first event matching `predicate`.
    public func request(_ command: Command, timeout: Duration = .seconds(8),
                        matching predicate: @escaping @Sendable (WatchEvent) -> Bool) async throws -> WatchEvent {
        try await sendAndWait(timeout: timeout, matching: predicate) { try await $0.write(command.frame) }
    }

    /// Runs `send`, then waits for the first event matching `predicate` (registered before sending).
    func sendAndWait(timeout: Duration, matching predicate: @escaping @Sendable (WatchEvent) -> Bool,
                     send: @escaping @Sendable (WakeupDriver) async throws -> Void) async throws -> WatchEvent {
        let id = UUID()
        return try await withCheckedThrowingContinuation { cont in
            waiters[id] = (predicate, cont)
            Task {
                do { try await send(self) } catch { await self.fail(id, error) }
                try? await Task.sleep(for: timeout)
                await self.fail(id, WatchError.timeout)
            }
        }
    }

    private func fail(_ id: UUID, _ error: Error) {
        guard let w = waiters.removeValue(forKey: id) else { return }
        w.cont.resume(throwing: error)
    }

    // MARK: flows

    /// Time, phone OS, device info. Throws `.timeout` if the watch never answers device info.
    public func handshake() async throws -> DeviceInfo {
        try await perform(.setTime(Date(), decoder.timeZone))
        // The phone-OS reply carries the platform code that decides the face image format.
        _ = try? await request(.phoneSystem, timeout: .seconds(3)) { if case .platform = $0 { return true }; return false }
        let event = try await request(.requestDeviceInfo) { if case .deviceInfo = $0 { return true }; return false }
        guard case let .deviceInfo(info) = event else { throw WatchError.timeout }
        _ = try? await request(.requestScreenInfo, timeout: .seconds(3)) { if case .screen = $0 { return true }; return false }
        return info
    }

    public func measure(_ kind: MeasureKind, timeout: Duration = .seconds(60)) async throws -> Sample {
        let event = try await request(.measure(kind, on: true), timeout: timeout) { event in
            if case let .sample(s) = event, s.kind == kind.sampleKind { return true }
            return false
        }
        try? await perform(.measure(kind, on: false))
        guard case let .sample(sample) = event else { throw WatchError.timeout }
        return sample
    }

    /// Requests history and returns every event received until the watch is quiet for 3 s (max 60 s).
    /// Events are also yielded on `events` as they arrive.
    public func sync(since: Date?) async throws -> [WatchEvent] {
        syncBuffer = []
        defer { syncBuffer = nil }
        let start = Date()
        try await perform(.syncHistory(since: since, decoder.timeZone))
        try await perform(.syncSleep(day: Date(), decoder.timeZone))
        lastEventAt = Date()
        while Date().timeIntervalSince(lastEventAt) < 3, Date().timeIntervalSince(start) < 60 {
            try await Task.sleep(for: .milliseconds(300))
        }
        return syncBuffer ?? []
    }

    /// Experimental photo-face install. Layout from the reference app's source; not yet tried on a watch.
    /// `pixels` = RGB565 big-endian, `screen.width x screen.height`. Returns only after the watch asked
    /// for the package after the last one.
    public func installPhotoFace(pixels: Data, style: PhotoFaceStyle, consent: UserConsent,
                                 progress: @escaping @Sendable (Double) -> Void) async throws {
        guard family != .sifli else {
            throw WatchError.protocolUnconfirmed("SiFli watches use a different picture transfer")
        }
        if let p = platform?.platform, PhotoFace.compressedPlatforms.contains(p) {
            throw WatchError.protocolUnconfirmed("This watch needs a compressed image format")
        }
        guard let screen, pixels.count == screen.width * screen.height * 2 else {
            throw WatchError.protocolUnconfirmed("Screen size unknown or image size mismatch")
        }
        guard transport.maximumWriteLength >= PhotoFace.writeSize else {
            throw WatchError.protocolUnconfirmed("Bluetooth packet size too small for picture transfer")
        }
        let packages = PhotoFace.packages(pixels)
        try await perform(.highSpeed(true)) // as the reference app's album screen does
        do {
            try await sendPhotoPackages(packages, fileSize: pixels.count, progress: progress)
        } catch {
            try? await perform(.highSpeed(false))
            throw error
        }
        // Classic style only: on the user's watch the face showed after `AB…9C`, not after `EA…0D` (logs 11-10, 11-12).
        try await write(PhotoFace.style(red: style.red, green: style.green, blue: style.blue,
                                        font: style.font, location: style.location))
        try await write(PhotoFace.puzzleFlag(false))
        try? await perform(.highSpeed(false))
    }

    /// Re-sends only the style (time colour, font, position, data widget) for the installed photo face.
    /// Used by the in-app style tester; changes appearance only.
    public func applyPhotoFaceStyle(_ style: PhotoFaceStyle) async throws {
        try await write(PhotoFace.frame(for: style))
    }

    private func sendPhotoPackages(_ packages: [[UInt8]], fileSize: Int,
                                   progress: @escaping @Sendable (Double) -> Void) async throws {
        try await write(PhotoFace.backgroundCount(1))
        var index = 0
        var sends = 0
        while index < packages.count {
            sends += 1
            guard sends <= packages.count * 3 else { throw WatchError.timeout } // the watch keeps asking for resends
            let package = packages[index]
            let info = PhotoFace.infoPacket(package: package, index: index, isLast: index == packages.count - 1,
                                            fileSize: fileSize)
            let content = PhotoFace.contentStream(package: package, index: index)
            let ack = try await sendAndWait(timeout: .seconds(10), matching: { e in
                if case .faceAck = e { return true }
                return false
            }) { d in
                try await d.writeRaw(info, pieceSize: PhotoFace.writeSize)
                try await d.writeRaw(content, pieceSize: PhotoFace.writeSize)
            }
            guard case let .faceAck(next) = ack else { throw WatchError.timeout }
            index = next
            progress(min(1, Double(index) / Double(packages.count)))
        }
    }

    public func updateFirmware(file: URL, consent: UserConsent) async throws {
        try await plugin.updateFirmware(file: file, consent: consent)
    }

    public func setFamily(_ family: DeviceFamily) {
        self.family = family
        self.plugin = DriverFactory.plugin(for: family)
    }
}

extension MeasureKind {
    public var sampleKind: SampleKind {
        switch self {
        case .heartRate: return .heartRate
        case .bloodOxygen: return .bloodOxygen
        case .bloodPressure: return .bloodPressure
        case .temperature: return .temperature
        }
    }
}
