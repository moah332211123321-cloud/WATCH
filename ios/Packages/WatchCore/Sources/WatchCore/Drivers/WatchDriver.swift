import Foundation

/// GATT channels used by the protocol (research/protocol.md §2).
public enum Channel: String, Sendable {
    case command   // 6E400001 service: write 6E400002, notify 6E400003
    case file      // 6E400011 service: write 6E400012, notify 6E400013
}

public enum GATT {
    public static let commandService = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let commandWrite = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let commandNotify = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let fileService = "6E400011-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let fileWrite = "6E400012-B5A3-F393-E0A9-E50E24DCCA9E"
    public static let fileNotify = "6E400013-B5A3-F393-E0A9-E50E24DCCA9E"
    // Family markers (only used to identify the chip family).
    public static let sifliService = "00000000-0000-0000-6473-5F696C666973"
    public static let bluetrumFotaService = "FF12"
    public static let nordicDfuService = "FE59"
}

public enum DeviceFamily: String, Codable, CaseIterable, Sendable {
    case generic, sifli, bluetrum, nordic, hisilicon
}

public enum WatchError: Error, Equatable, Sendable {
    case notConnected
    case timeout
    /// The watch reports it lacks the feature.
    case unsupportedByWatch
    /// The protocol for this is not confirmed; we do not send guesses that could change the watch.
    case protocolUnconfirmed(String)
    /// The vendor needs its private server for this (license, market, firmware download).
    case needsVendorServer(String)
    /// Destructive or risky action without the user's explicit confirmation.
    case consentRequired
}

/// Bytes in and out. The app implements it with CoreBluetooth; tests use a fake.
public protocol WatchTransport: AnyObject, Sendable {
    func write(_ data: Data, channel: Channel) async throws
    /// Largest single write (ATT MTU - 3). 20 if unknown.
    var maximumWriteLength: Int { get }
}

/// Explicit consent object for risky operations; created only by a confirmation UI.
public struct UserConsent: Sendable, Equatable {
    public let confirmedPhrase: String
    public let date: Date
    public init(confirmedPhrase: String, date: Date = Date()) {
        self.confirmedPhrase = confirmedPhrase
        self.date = date
    }
}

/// Family-specific parts: firmware (research/devices.md §1). Photo faces live in WakeupDriver.
public protocol FamilyPlugin: Sendable {
    var family: DeviceFamily { get }
    func updateFirmware(file: URL, consent: UserConsent) async throws
}

/// The high-level interface the app uses. One implementation per protocol (today: WakeupDriver).
public protocol WatchDriver: Sendable {
    var family: DeviceFamily { get async }
    var capabilities: Capabilities { get async }
    var events: AsyncStream<WatchEvent> { get }
    func handshake() async throws -> DeviceInfo
    func perform(_ command: Command, consent: UserConsent?) async throws
    func measure(_ kind: MeasureKind, timeout: Duration) async throws -> Sample
    func sync(since: Date?) async throws -> [WatchEvent]
    func receive(_ data: Data, channel: Channel) async
}

public enum DriverFactory {
    /// Picks the chip family from the GATT services the watch exposes.
    public static func family(forServiceUUIDs uuids: [String]) -> DeviceFamily {
        let set = Set(uuids.map { $0.uppercased() })
        if set.contains(GATT.sifliService) { return .sifli }
        if set.contains(GATT.bluetrumFotaService) || set.contains(fullUUID(GATT.bluetrumFotaService)) { return .bluetrum }
        if set.contains(GATT.nordicDfuService) || set.contains(fullUUID(GATT.nordicDfuService)) { return .nordic }
        return .generic // HiSilicon has no known BLE marker; it is set later if identified
    }

    public static func plugin(for family: DeviceFamily) -> FamilyPlugin {
        UnconfirmedFamilyPlugin(family: family)
    }

    static func fullUUID(_ short: String) -> String { "0000\(short)-0000-1000-8000-00805F9B34FB" }
}

/// Firmware update is never performed: the flow is unconfirmed and a bad flash can brick the watch.
public struct UnconfirmedFamilyPlugin: FamilyPlugin {
    public let family: DeviceFamily

    public func updateFirmware(file: URL, consent: UserConsent) async throws {
        // Never flash without a confirmed flow (CLAUDE.md). Consent alone is not enough.
        throw WatchError.protocolUnconfirmed("Firmware update flow for \(family.rawValue) is not confirmed on this watch")
    }
}
