import Foundation

/// A time window on the watch (hour/minute pairs, local wall-clock).
public struct TimeWindow: Equatable, Sendable {
    public var startHour: Int, startMinute: Int, endHour: Int, endMinute: Int
    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = startHour; self.startMinute = startMinute
        self.endHour = endHour; self.endMinute = endMinute
    }
}

/// Weekday bit mask as sent by the reference app (`BleUtil.bit2Byte`). Bit order is unconfirmed:
/// bit 0 = Monday … bit 6 = Sunday is assumed.
public struct Weekdays: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let monday = Weekdays(rawValue: 1 << 0)
    public static let tuesday = Weekdays(rawValue: 1 << 1)
    public static let wednesday = Weekdays(rawValue: 1 << 2)
    public static let thursday = Weekdays(rawValue: 1 << 3)
    public static let friday = Weekdays(rawValue: 1 << 4)
    public static let saturday = Weekdays(rawValue: 1 << 5)
    public static let sunday = Weekdays(rawValue: 1 << 6)
    public static let all: Weekdays = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
}

/// What a measurement command measures. Request codes are assumed to equal the reply sub-codes
/// seen in `HealthDataAnalyzer` (single values); unconfirmed.
public enum MeasureKind: UInt8, CaseIterable, Sendable {
    case heartRate = 0x09
    case bloodOxygen = 0x11
    case bloodPressure = 0x21
    case temperature = 0x81
}

/// Every command this app knows how to send. Bytes come from research/protocol.md and
/// research/evidence/E1-commands.tsv. Confidence per case is in the doc comment:
/// D = derived from the reference app's byte templates, I = parameter order inferred.
public enum Command: Equatable, Sendable {
    /// D. `AB 00 0B FF 93 80 00 YYhi YYlo MM DD hh mm ss` (local wall-clock).
    case setTime(Date, TimeZone)
    /// D (constant observed in the reference app). Meaning of `01 02` unconfirmed for iOS.
    case phoneSystem
    /// D. `AB 00 04 FF 92 80 01`.
    case requestDeviceInfo
    /// D. `AB 00 03 FF AA 80`.
    case requestSerialNumber
    /// D. `AB 00 03 FF 71 80`.
    case findWatch
    /// D frame, I codes. `AB 00 04 FF 31 <kind> <on>`.
    case measure(MeasureKind, on: Bool)
    /// D. `AB 00 04 FF 78 80 <on>` — automatic hourly measurement.
    case hourlyMeasurement(on: Bool)
    /// D. `AB 00 04 FF 77 80 <on>`.
    case raiseToWake(on: Bool)
    /// D. `AB 00 04 FF 79 80 <on>` — shake the watch to take a photo.
    case shakeToTakePhoto(on: Bool)
    /// D. `AB 00 04 FF 7C 80 <v>`; value 1 = 12-hour assumed (I).
    case twelveHourClock(Bool)
    /// D. `AB 00 04 FF 7B 80 <code>`; language codes unknown (I).
    case language(code: UInt8)
    /// D. `AB 00 04 FF EF 80 <v>`; 0 = Celsius assumed (I).
    case temperatureUnitFahrenheit(Bool)
    /// D order (from call sites): on, start h/m, end h/m, interval minutes.
    case sedentaryReminder(on: Bool, window: TimeWindow, intervalMinutes: Int)
    /// D order: on, start h/m, end h/m, interval minutes.
    case drinkWaterReminder(on: Bool, window: TimeWindow, intervalMinutes: Int)
    /// D order: on, start h/m, end h/m.
    case doNotDisturb(on: Bool, window: TimeWindow)
    /// D frame, I order: index, enabled, hour, minute, repeat mask, flags.
    case alarm(index: UInt8, enabled: Bool, hour: Int, minute: Int, repeats: Weekdays, flags: UInt8)
    /// D. `AB 00 0E FF 51 80 00 Y M D 00 00 Y M D h m` (year - 2000). `since == nil` → from today 00:00.
    case syncHistory(since: Date?, TimeZone)
    /// D. `AB 00 07 FF 52 80 00 Y M D` (year - 2000).
    case syncSleep(day: Date, TimeZone)
    /// D. `AB 00 04 FF 23 80 00`. Destructive — the UI requires a typed confirmation.
    case clearData
    /// D. `AB 00 03 FF FF 80`. Destructive — the UI requires a typed confirmation.
    case factoryReset
    /// D. `EA 00 03 00 0B 02` — reply to the watch's heartbeat.
    case heartbeatReply
    /// D. `EA 00 03 00 14 01` — ask for screen size.
    case requestScreenInfo
    /// Source (`BleWatchServiceImpl.switchSpeed`, used by AlbumDialActivity around picture transfers):
    /// `AB 00 04 FF 87 80 01` = high-speed BLE on, `… 00` = off.
    case highSpeed(Bool)

    public var frame: Frame {
        switch self {
        case let .setTime(date, zone):
            let c = Self.components(date, zone)
            return .classic([0x93, 0x80, 0x00, UInt8(c.year >> 8), UInt8(c.year & 0xFF),
                             UInt8(c.month), UInt8(c.day), UInt8(c.hour), UInt8(c.minute), UInt8(c.second)])
        case .phoneSystem: return .classic([0x20, 0x80, 0x01, 0x02])
        case .requestDeviceInfo: return .classic([0x92, 0x80, 0x01])
        case .requestSerialNumber: return .classic([0xAA, 0x80])
        case .findWatch: return .classic([0x71, 0x80])
        case let .measure(kind, on): return .classic([0x31, kind.rawValue, on ? 1 : 0])
        case let .hourlyMeasurement(on): return .classic([0x78, 0x80, on ? 1 : 0])
        case let .raiseToWake(on): return .classic([0x77, 0x80, on ? 1 : 0])
        case let .shakeToTakePhoto(on): return .classic([0x79, 0x80, on ? 1 : 0])
        case let .twelveHourClock(v): return .classic([0x7C, 0x80, v ? 1 : 0])
        case let .language(code): return .classic([0x7B, 0x80, code])
        case let .temperatureUnitFahrenheit(f): return .classic([0xEF, 0x80, f ? 1 : 0])
        case let .sedentaryReminder(on, w, interval):
            return .classic([0x75, 0x80, on ? 1 : 0] + Self.window(w) + [Self.byte(interval)])
        case let .drinkWaterReminder(on, w, interval):
            return .classic([0x53, 0x80, on ? 1 : 0] + Self.window(w) + [Self.byte(interval)])
        case let .doNotDisturb(on, w):
            return .classic([0x76, 0x80, on ? 1 : 0] + Self.window(w))
        case let .alarm(index, enabled, hour, minute, repeats, flags):
            return .classic([0x73, 0x80, index, enabled ? 1 : 0, Self.byte(hour), Self.byte(minute),
                             repeats.rawValue, flags])
        case let .syncHistory(since, zone):
            if let since {
                let c = Self.components(since, zone)
                let d: [UInt8] = [Self.byte(c.year - 2000), UInt8(c.month), UInt8(c.day)]
                return .classic([0x51, 0x80, 0x00] + d + [0x00, 0x00] + d + [UInt8(c.hour), UInt8(c.minute)])
            }
            let c = Self.components(Date(), zone)
            return .classic([0x51, 0x80, 0x00, Self.byte(c.year - 2000), UInt8(c.month), UInt8(c.day),
                             0, 0, 0, 0, 0, 0, 0])
        case let .syncSleep(day, zone):
            let c = Self.components(day, zone)
            return .classic([0x52, 0x80, 0x00, Self.byte(c.year - 2000), UInt8(c.month), UInt8(c.day)])
        case .clearData: return .classic([0x23, 0x80, 0x00])
        case .factoryReset: return .classic([0xFF, 0x80])
        case .heartbeatReply: return .extended([0x0B, 0x02])
        case .requestScreenInfo: return .extended([0x14, 0x01])
        case let .highSpeed(on): return .classic([0x87, 0x80, on ? 1 : 0])
        }
    }

    public var isDestructive: Bool {
        switch self {
        case .clearData, .factoryReset: return true
        default: return false
        }
    }

    // MARK: helpers

    struct Parts { var year, month, day, hour, minute, second: Int }

    static func components(_ date: Date, _ zone: TimeZone) -> Parts {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return Parts(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1,
                     hour: c.hour ?? 0, minute: c.minute ?? 0, second: c.second ?? 0)
    }

    static func byte(_ v: Int) -> UInt8 { UInt8(clamping: v) }

    static func window(_ w: TimeWindow) -> [UInt8] {
        [byte(w.startHour), byte(w.startMinute), byte(w.endHour), byte(w.endMinute)]
    }
}
