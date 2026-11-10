import Foundation

/// Firmware / identity data from the `92` reply (research/protocol.md §5).
public struct DeviceInfo: Equatable, Sendable {
    public var firmwareVersion: String
    public var bandVersionCode: Int
    public var rawCapabilityBytes: [Int: UInt8]   // keyed by absolute frame offset (11…18)
    public var capabilities: Capabilities

    public init(firmwareVersion: String, bandVersionCode: Int, rawCapabilityBytes: [Int: UInt8]) {
        self.firmwareVersion = firmwareVersion
        self.bandVersionCode = bandVersionCode
        self.rawCapabilityBytes = rawCapabilityBytes
        self.capabilities = Capabilities(deviceInfoBytes: rawCapabilityBytes)
    }

    /// Screen from the byte-18 table (fallback when the watch does not answer `EA 14 01`).
    public var tableScreen: ScreenInfo? { rawCapabilityBytes[18].flatMap(ScreenTable.screen(code:)) }
}

public struct DaySummary: Equatable, Sendable {
    public var steps: Int
    public var kilocalories: Int
    public var lightSleepMinutes: Int
    public var deepSleepMinutes: Int
    public var awakeCount: Int
    public var sportSeconds: Int?
    public var sportCount: Int?

    public init(steps: Int, kilocalories: Int, lightSleepMinutes: Int, deepSleepMinutes: Int, awakeCount: Int,
                sportSeconds: Int?, sportCount: Int?) {
        self.steps = steps; self.kilocalories = kilocalories
        self.lightSleepMinutes = lightSleepMinutes; self.deepSleepMinutes = deepSleepMinutes
        self.awakeCount = awakeCount; self.sportSeconds = sportSeconds; self.sportCount = sportCount
    }
}

public enum SampleKind: String, Codable, CaseIterable, Sendable {
    case heartRate, bloodOxygen, bloodPressure, temperature, stress, steps, kilocalories, sleep
}

/// One value from the watch. `isLive` = real-time stream rather than a stored measurement.
public struct Sample: Equatable, Sendable {
    public var kind: SampleKind
    public var date: Date
    public var value: Double
    public var value2: Double?        // diastolic for blood pressure
    public var isLive: Bool

    public init(kind: SampleKind, date: Date, value: Double, value2: Double? = nil, isLive: Bool) {
        self.kind = kind; self.date = date; self.value = value; self.value2 = value2; self.isLive = isLive
    }
}

public struct SleepSegment: Equatable, Sendable {
    public var start: Date
    public var minutes: Int
    /// Raw stage code from the watch. Mapping (light/deep/awake/REM) is unconfirmed.
    public var stageCode: UInt8
}

/// Screen of the watch. `shape`: 0 = round, 1 = square, 2 = rectangle (reference app's screenType).
public struct ScreenInfo: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var shape: Int
    public init(width: Int, height: Int, shape: Int) { self.width = width; self.height = height; self.shape = shape }
    public var isRound: Bool { shape == 0 }
}

/// Reply to the phone-OS command (`AB … 20`, `ConnectAnalyzer.getPairingType` → `DeviceLocal`).
public struct PlatformInfo: Equatable, Sendable {
    /// Chip platform code (`DeviceLocal.getPlatform`, byte 6). 9 and 12 use compressed face images.
    public var platform: Int
    /// Byte 8 flags: bit0 dual-mode, bit2 new pay code, bit4 pressure, bit5 own file transfer, bit7 switch receive.
    public var flags: UInt8
    public var deviceType: Int   // byte 9
    public var otaType: Int      // byte 10
}

/// A workout recorded on the watch (`AB … B7`, `DataSyncProxy.saveSport`).
public struct SportRecord: Equatable, Sendable {
    public var type: Int
    public var start: Date
    public var durationSeconds: Int
    public var steps: Int
    public var kilocalories: Int
    public var distanceMeters: Int
    public var averageHeartRate: Int
}

/// Hourly record (`AB … 51 20`, `DataSyncProxy.hourlyMeasure1`): totals for the hour before `hour`.
public struct HourlyRecord: Equatable, Sendable {
    public var hourStart: Date
    public var steps: Int
    public var kilocalories: Int
    public var heartRate: Int
    public var bloodOxygen: Int
    public var systolic: Int
    public var diastolic: Int
}

/// Everything the decoder can turn a frame into.
public enum WatchEvent: Equatable, Sendable {
    /// Battery percent (`AB … 91`, `CommonAnalyzer.getBattery`, byte 7).
    case battery(Int)
    /// The watch asks the phone to ring (`AB … 7D`, b6 1 = start, 0 = stop).
    case findPhone(Bool)
    /// Shutter pressed on the watch (`AB … 79` from the watch, `CommonAnalyzer.sendTake`).
    case cameraShutter
    case hourly(HourlyRecord)
    case platform(PlatformInfo)
    case screen(ScreenInfo)
    case sport(SportRecord)
    /// Photo-face answer: index of the package the watch wants next.
    case faceAck(nextIndex: Int)
    /// A notification that is not an AB/EA frame (passed through unchanged, like the reference app).
    case raw([UInt8])
    case deviceInfo(DeviceInfo)
    case daySummary(DaySummary)
    case sample(Sample)
    case sleep(SleepSegment)
    /// The watch's heartbeat; the driver answers with `Command.heartbeatReply`.
    case heartbeat
    /// A frame we do not decode yet (kept for the packet log).
    case unknown(Frame)
}
