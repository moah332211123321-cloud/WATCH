import AudioToolbox
import CoreBluetooth
import Foundation
import Observation
import SwiftData
import WatchCore

struct PacketLine: Identifiable {
    let id = UUID()
    let date: Date
    let outgoing: Bool
    let hex: String
}

/// App-wide device state. Views read it and call its methods; it is the only owner of the driver.
@MainActor @Observable
final class DeviceController {
    enum Link: Equatable {
        case bluetoothOff, bluetoothUnauthorized, idle, scanning, connecting, connected, failed(String)
    }

    var link: Link = .idle
    var discovered: [DiscoveredWatch] = []
    var connectedID: UUID?
    var connectedName = ""
    var info: DeviceInfo?
    var capabilities = Capabilities()
    var family: DeviceFamily = .generic
    var lastSync: Date?
    var isSyncing = false
    var syncError: String?
    var liveHeartRate: Int?
    var packetLog: [PacketLine] = []
    var screen: ScreenInfo?
    var platform: PlatformInfo?
    var battery: Int?
    /// True while the phone rings because the watch asked "find my phone".
    var isFindingPhone = false
    @ObservationIgnored private var ringTask: Task<Void, Never>?

    @ObservationIgnored private let ble = BLECentral()
    @ObservationIgnored private(set) var driver: WakeupDriver?
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored var context: ModelContext?
    @ObservationIgnored let health = HealthKitBridge()
    @ObservationIgnored private var userInitiatedDisconnect = false

    init() {
        ble.onEvent = { [weak self] event in self?.handle(event) }
        lastSync = UserDefaults.standard.object(forKey: "lastSync") as? Date
    }

    var isConnected: Bool { link == .connected }

    // MARK: scanning / connection

    func startScan() {
        discovered = []
        link = .scanning
        ble.startScan()
    }

    func stopScan() {
        ble.stopScan()
        if link == .scanning { link = .idle }
    }

    func connect(_ watch: DiscoveredWatch) {
        stopScan()
        connectedName = watch.name
        link = .connecting
        ble.connect(watch.id)
    }

    /// Reconnects to the primary saved watch (called at launch and after unexpected disconnects).
    func reconnectSaved() {
        guard let context, let saved = try? context.fetch(FetchDescriptor<DeviceRecord>(
            predicate: #Predicate { $0.isPrimary })).first else { return }
        connectedName = saved.name
        family = saved.family
        link = .connecting
        ble.connect(saved.id)
    }

    func disconnect() {
        userInitiatedDisconnect = true
        ble.disconnect()
    }

    func forget(_ record: DeviceRecord) {
        if record.id == connectedID { disconnect() }
        context?.delete(record)
        try? context?.save()
    }

    private func handle(_ event: BLEEvent) {
        switch event {
        case let .powerChanged(state):
            switch state {
            case .poweredOn:
                if link == .bluetoothOff || link == .bluetoothUnauthorized { link = .idle }
                if link == .idle { reconnectSaved() }
            case .unauthorized: link = .bluetoothUnauthorized
            default: link = .bluetoothOff
            }
        case let .discovered(watch):
            if let i = discovered.firstIndex(where: { $0.id == watch.id }) { discovered[i] = watch }
            else { discovered.append(watch) }
        case .connected:
            break // waiting for services
        case let .ready(id, services):
            guard connectedID != id || driver == nil else { return }
            connectedID = id
            family = DriverFactory.family(forServiceUUIDs: services)
            let driver = WakeupDriver(transport: ble, family: family) { [weak self] outgoing, bytes in
                let line = PacketLine(date: Date(), outgoing: outgoing, hex: bytes.hex)
                Task { @MainActor in self?.appendLog(line) }
            }
            self.driver = driver
            listen(to: driver)
            Task { await self.finishConnect(id: id, driver: driver) }
        case let .data(data, channel):
            guard let driver else { return }
            Task { await driver.receive(data, channel: channel) }
        case let .disconnected(id, _):
            guard id == connectedID else { return }
            tearDown()
            link = .idle
            if !userInitiatedDisconnect { reconnectSaved() } // iOS keeps the request pending until in range
            userInitiatedDisconnect = false
        case let .failed(_, error):
            tearDown()
            link = .failed(error?.localizedDescription ?? S("Could not connect."))
        }
    }

    private func finishConnect(id: UUID, driver: WakeupDriver) async {
        do {
            let info = try await driver.handshake()
            self.info = info
            self.capabilities = await driver.capabilities
            self.screen = await driver.screen
            self.platform = await driver.platform
            link = .connected
            saveDevice(id: id, info: info)
            await sync()
        } catch {
            // Connected over BLE but the watch did not answer the protocol: say so, keep the link.
            link = .failed(describe(error))
        }
    }

    private func saveDevice(id: UUID, info: DeviceInfo) {
        guard let context else { return }
        let all = (try? context.fetch(FetchDescriptor<DeviceRecord>())) ?? []
        for d in all { d.isPrimary = d.id == id }
        let record = all.first(where: { $0.id == id }) ?? {
            let r = DeviceRecord(id: id, name: connectedName, family: family)
            context.insert(r)
            return r
        }()
        record.firmware = info.firmwareVersion
        record.bandVersionCode = info.bandVersionCode
        record.familyRaw = family.rawValue
        record.lastSeen = Date()
        record.isPrimary = true
        try? context.save()
    }

    private func tearDown() {
        eventTask?.cancel()
        eventTask = nil
        driver = nil
        connectedID = nil
        liveHeartRate = nil
    }

    private func listen(to driver: WakeupDriver) {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            for await event in driver.events {
                guard let self else { return }
                if case let .sample(s) = event, s.kind == .heartRate, s.isLive { self.liveHeartRate = Int(s.value) }
                if case let .battery(level) = event { self.battery = level }
                if case let .findPhone(on) = event { on ? self.startRinging() : self.stopRinging() }
                if let context = self.context {
                    HealthRepository(context: context).store(event, deviceID: self.connectedID)
                }
            }
        }
    }

    /// Plays the alert sound and vibrates every second for up to 30 s (only while Sawar is open:
    /// iOS does not let a background app play sound without an audio session).
    func startRinging() {
        ringTask?.cancel()
        isFindingPhone = true
        ringTask = Task { [weak self] in
            for _ in 0..<30 {
                if Task.isCancelled { break }
                AudioServicesPlaySystemSound(1005)
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                try? await Task.sleep(for: .seconds(1))
            }
            self?.isFindingPhone = false
        }
    }

    func stopRinging() {
        ringTask?.cancel()
        ringTask = nil
        isFindingPhone = false
    }

    private func appendLog(_ line: PacketLine) {
        packetLog.append(line)
        if packetLog.count > 2000 { packetLog.removeFirst(packetLog.count - 2000) }
    }

    // MARK: actions (views call these)

    func sync() async {
        guard let driver, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            _ = try await driver.sync(since: lastSync)
            lastSync = Date()
            UserDefaults.standard.set(lastSync, forKey: "lastSync")
            if UserDefaults.standard.bool(forKey: "exportToHealth") { await exportPending() }
            syncError = nil
        } catch {
            syncError = describe(error)
        }
    }

    /// Sends a command; throws a user-facing error when not connected or refused.
    func send(_ command: Command, consent: UserConsent? = nil) async throws {
        guard let driver else { throw WatchError.notConnected }
        try await driver.perform(command, consent: consent)
    }

    func measure(_ kind: MeasureKind) async throws -> Sample {
        guard let driver else { throw WatchError.notConnected }
        return try await driver.measure(kind, timeout: .seconds(60))
    }

    /// Experimental: layout from the reference app's source, not yet tried on a watch.
    func installPhotoFace(pixels: Data, style: PhotoFaceStyle, consent: UserConsent,
                          progress: @escaping @Sendable (Double) -> Void) async throws {
        guard let driver else { throw WatchError.notConnected }
        try await driver.installPhotoFace(pixels: pixels, style: style, consent: consent, progress: progress)
    }

    func applyPhotoFaceStyle(_ style: PhotoFaceStyle) async throws {
        guard let driver else { throw WatchError.notConnected }
        try await driver.applyPhotoFaceStyle(style)
    }

    func updateFirmware(file: URL, consent: UserConsent) async throws {
        guard let driver else { throw WatchError.notConnected }
        try await driver.updateFirmware(file: file, consent: consent)
    }

    /// Exports device samples not yet in Apple Health.
    func exportPending() async {
        guard let context else { return }
        let device = SampleSource.device.rawValue
        let pending = (try? context.fetch(FetchDescriptor<HealthSampleRecord>(
            predicate: #Predicate { $0.sourceRaw == device && !$0.exportedToHealth }))) ?? []
        for sample in pending {
            if await health.export(metric: sample.metric, date: sample.date, value: sample.value, value2: sample.value2) {
                sample.exportedToHealth = true
            }
        }
        try? context.save()
    }
}
