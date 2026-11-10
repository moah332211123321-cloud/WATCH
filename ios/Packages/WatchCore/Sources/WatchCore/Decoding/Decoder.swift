import Foundation

/// Turns frames from the watch into events. Layouts: research/protocol.md §5.
/// Offsets are absolute frame offsets (`b6` = first byte after command and sub).
public struct WatchDecoder: Sendable {
    public var timeZone: TimeZone
    public var now: @Sendable () -> Date

    public init(timeZone: TimeZone = .current, now: @escaping @Sendable () -> Date = { Date() }) {
        self.timeZone = timeZone
        self.now = now
    }

    public func decode(_ frame: Frame) -> WatchEvent {
        let b = frame.bytes
        func at(_ i: Int) -> Int? { i < b.count ? Int(b[i]) : nil }

        let cmd = frame.command ?? 0, sub = frame.sub ?? 0
        switch (frame.kind, cmd, sub) {
        case (.classic, 0x92, _):
            guard let v1 = at(6), let v2 = at(7), let hi = at(9), let lo = at(10) else { break }
            var caps: [Int: UInt8] = [:]
            for i in [11, 12, 15, 16, 17, 18] where i < b.count { caps[i] = b[i] }
            return .deviceInfo(DeviceInfo(firmwareVersion: String(format: "%ld.%02ld", v1, v2),
                                          bandVersionCode: hi << 8 | lo, rawCapabilityBytes: caps))

        case (.classic, 0x51, 0x08):
            guard b.count >= 16 else { break }
            let steps = Int(b[6]) << 16 | Int(b[7]) << 8 | Int(b[8])
            let kcal = Int(b[9]) << 16 | Int(b[10]) << 8 | Int(b[11])
            return .daySummary(DaySummary(
                steps: steps, kilocalories: kcal,
                lightSleepMinutes: Int(b[12]) * 60 + Int(b[13]),
                deepSleepMinutes: Int(b[14]) * 60 + Int(b[15]),
                awakeCount: at(16) ?? 0,
                sportSeconds: b.count >= 19 ? Int(b[17]) << 8 | Int(b[18]) : nil,
                sportCount: at(19)))

        case (.classic, 0x51, 0x11...0x14):
            guard let date = deviceDate(b, from: 6), let v = at(11) else { break }
            switch sub {
            case 0x11: return .sample(Sample(kind: .heartRate, date: date, value: Double(v), isLive: false))
            case 0x12: return .sample(Sample(kind: .bloodOxygen, date: date, value: Double(v), isLive: false))
            case 0x13: // I: whole degrees + tenths
                return .sample(Sample(kind: .temperature, date: date,
                                      value: Double(v) + Double(at(12) ?? 0) / 10, isLive: false))
            default:   // I: systolic, diastolic
                guard let dia = at(12) else { break }
                return .sample(Sample(kind: .bloodPressure, date: date, value: Double(v),
                                      value2: Double(dia), isLive: false))
            }

        case (.classic, 0x51, 0x0B):
            guard let date = deviceDate(b, from: 6), let v = at(11) else { break }
            return .sample(Sample(kind: .stress, date: date, value: Double(v), isLive: false))

        case (.classic, 0x31, _):
            // I: value right after the sub-code.
            guard let v = at(6) else { break }
            let live = sub & 0x01 == 0 // 0x0A, 0x12, 0x22 = real-time; 0x09, 0x11, 0x21 = single
            switch sub {
            case 0x09, 0x0A: return .sample(Sample(kind: .heartRate, date: now(), value: Double(v), isLive: live))
            case 0x11, 0x12: return .sample(Sample(kind: .bloodOxygen, date: now(), value: Double(v), isLive: live))
            case 0x21, 0x22:
                guard let dia = at(7) else { break }
                return .sample(Sample(kind: .bloodPressure, date: now(), value: Double(v),
                                      value2: Double(dia), isLive: live))
            case 0x81:
                return .sample(Sample(kind: .temperature, date: now(),
                                      value: Double(v) + Double(at(7) ?? 0) / 10, isLive: false))
            default: break
            }

        case (.classic, 0x52, _):
            guard let start = deviceDate(b, from: 6), let code = at(11), let hi = at(12), let lo = at(13) else { break }
            return .sleep(SleepSegment(start: start, minutes: hi << 8 | lo, stageCode: UInt8(code)))

        case (.extended, 0x0B, _) where sub != 0x02:
            return .heartbeat

        default:
            break
        }
        return .unknown(frame)
    }

    /// `Y-2000, M, D, h, m` starting at `offset`, in the watch's (= phone's) local time.
    func deviceDate(_ b: [UInt8], from offset: Int) -> Date? {
        guard b.count >= offset + 5 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var c = DateComponents()
        c.year = 2000 + Int(b[offset]); c.month = Int(b[offset + 1]); c.day = Int(b[offset + 2])
        c.hour = Int(b[offset + 3]); c.minute = Int(b[offset + 4])
        guard (1...12).contains(c.month!), (1...31).contains(c.day!), c.hour! < 24, c.minute! < 60 else { return nil }
        return cal.date(from: c)
    }
}
