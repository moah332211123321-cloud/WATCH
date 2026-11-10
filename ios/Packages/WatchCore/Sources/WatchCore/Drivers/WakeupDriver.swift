import Foundation

/// Driver for the shared AB/EA protocol used by every family. Family-specific transfers go to `plugin`.
public actor WakeupDriver: WatchDriver {
    public private(set) var family: DeviceFamily
    public private(set) var capabilities = Capabilities()
    public private(set) var deviceInfo: DeviceInfo?
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
        let bytes = frame.bytes
        log?(true, bytes)
        let size = max(20, transport.maximumWriteLength)
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
        for frame in reassembler.feed([UInt8](data)) {
            log?(false, frame.bytes)
            let event = decoder.decode(frame)
            lastEventAt = Date()
            if case .heartbeat = event { try? await write(Command.heartbeatReply.frame) }
            if case let .deviceInfo(info) = event {
                deviceInfo = info
                capabilities = info.capabilities
            }
            syncBuffer?.append(event)
            continuation.yield(event)
            for (id, w) in waiters where w.predicate(event) {
                waiters[id] = nil
                w.cont.resume(returning: event)
            }
        }
    }

    /// Writes `command` and waits for the first event matching `predicate`.
    public func request(_ command: Command, timeout: Duration = .seconds(8),
                        matching predicate: @escaping @Sendable (WatchEvent) -> Bool) async throws -> WatchEvent {
        let id = UUID()
        return try await withCheckedThrowingContinuation { cont in
            waiters[id] = (predicate, cont)
            Task {
                do { try await self.write(command.frame) } catch { await self.fail(id, error) }
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
        try await perform(.phoneSystem)
        let event = try await request(.requestDeviceInfo) { if case .deviceInfo = $0 { return true }; return false }
        guard case let .deviceInfo(info) = event else { throw WatchError.timeout }
        try? await perform(.requestScreenInfo)
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

    public func installFace(imageRGB565: Data, width: Int, height: Int) async throws -> TransferProgress {
        try await plugin.installFace(imageRGB565: imageRGB565, width: width, height: height)
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
