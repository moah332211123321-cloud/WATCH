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

/// Everything the decoder can turn a frame into.
public enum WatchEvent: Equatable, Sendable {
    case deviceInfo(DeviceInfo)
    case daySummary(DaySummary)
    case sample(Sample)
    case sleep(SleepSegment)
    /// The watch's heartbeat; the driver answers with `Command.heartbeatReply`.
    case heartbeat
    /// A frame we do not decode yet (kept for the packet log).
    case unknown(Frame)
}
