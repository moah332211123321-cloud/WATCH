import XCTest
@testable import WatchCore

/// Reply layouts are derived from the reference app's parsers (research/protocol.md §5); the byte
/// strings below are constructed from those layouts, not captured from a watch.
final class DecoderTests: XCTestCase {
    let utc = TimeZone(identifier: "UTC")!
    lazy var decoder = WatchDecoder(timeZone: utc, now: { Date(timeIntervalSince1970: 0) })

    func frame(_ hex: String) -> Frame {
        let bytes = hex.split(separator: " ").map { UInt8($0, radix: 16)! }
        return Frame(bytes: bytes)!
    }

    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testDeviceInfo() {
        let e = decoder.decode(frame("AB 00 10 FF 92 80 01 05 00 01 2C 06 00 00 00 86 00 44 00"))
        guard case let .deviceInfo(info) = e else { return XCTFail("\(e)") }
        XCTAssertEqual(info.firmwareVersion, "1.05")
        XCTAssertEqual(info.bandVersionCode, 300)
        XCTAssertEqual(info.capabilities[.license], .supported)
        XCTAssertEqual(info.capabilities[.firmwareUpdate], .supported)
        XCTAssertEqual(info.capabilities[.sleep], .supported)
        XCTAssertEqual(info.capabilities[.twelveHourClock], .supported)
        XCTAssertEqual(info.capabilities[.menstrual], .supported)
        XCTAssertEqual(info.capabilities[.sedentaryReminder], .supported)
        XCTAssertEqual(info.capabilities[.weather], .supported)
        XCTAssertEqual(info.capabilities[.bloodPressure], .unknown) // byte 16 table not decoded
    }

    func testCapabilityBitsOffMeansUnsupportedOnlyForDerivedFlags() {
        let e = decoder.decode(frame("AB 00 10 FF 92 80 01 05 00 01 2C 00 00 00 00 00 00 00 00"))
        guard case let .deviceInfo(info) = e else { return XCTFail() }
        XCTAssertEqual(info.capabilities[.license], .unsupported)
        XCTAssertEqual(info.capabilities[.sleep], .unknown) // inferred bit off never hides a feature
    }

    func testDaySummary() {
        let e = decoder.decode(frame("AB 00 0E FF 51 08 00 1F 40 00 01 2C 05 1E 01 0F 02"))
        guard case let .daySummary(s) = e else { return XCTFail("\(e)") }
        XCTAssertEqual(s.steps, 8000)
        XCTAssertEqual(s.kilocalories, 300)
        XCTAssertEqual(s.lightSleepMinutes, 330)
        XCTAssertEqual(s.deepSleepMinutes, 75)
        XCTAssertEqual(s.awakeCount, 2)
        XCTAssertNil(s.sportSeconds)
        XCTAssertNil(s.sportCount)
    }

    func testShortSummaryIsUnknown() {
        let e = decoder.decode(frame("AB 00 05 FF 51 08 00 1F"))
        guard case .unknown = e else { return XCTFail("\(e)") }
    }

    func testHeartRateHistory() {
        let e = decoder.decode(frame("AB 00 09 FF 51 11 1A 0B 0A 08 05 48"))
        guard case let .sample(s) = e else { return XCTFail("\(e)") }
        XCTAssertEqual(s.kind, .heartRate)
        XCTAssertEqual(s.value, 72)
        XCTAssertEqual(s.date, date(2026, 11, 10, 8, 5))
        XCTAssertFalse(s.isLive)
    }

    func testInvalidDateIsUnknown() {
        let e = decoder.decode(frame("AB 00 09 FF 51 11 1A 0D 0A 08 05 48")) // month 13
        guard case .unknown = e else { return XCTFail("\(e)") }
    }

    func testRealTimeHeartRate() {
        let e = decoder.decode(frame("AB 00 04 FF 31 0A 4B"))
        guard case let .sample(s) = e else { return XCTFail("\(e)") }
        XCTAssertEqual(s.kind, .heartRate)
        XCTAssertEqual(s.value, 75)
        XCTAssertTrue(s.isLive)
    }

    func testSingleBloodPressure() {
        let e = decoder.decode(frame("AB 00 05 FF 31 21 78 50"))
        guard case let .sample(s) = e else { return XCTFail("\(e)") }
        XCTAssertEqual(s.kind, .bloodPressure)
        XCTAssertEqual(s.value, 120)
        XCTAssertEqual(s.value2, 80)
        XCTAssertFalse(s.isLive)
    }

    func testSleepSegment() {
        let e = decoder.decode(frame("AB 00 0B FF 52 00 1A 0B 0A 01 1E 02 00 5A"))
        guard case let .sleep(seg) = e else { return XCTFail("\(e)") }
        XCTAssertEqual(seg.start, date(2026, 11, 10, 1, 30))
        XCTAssertEqual(seg.stageCode, 2)
        XCTAssertEqual(seg.minutes, 90)
    }

    func testHeartbeatAndUnknown() {
        guard case .heartbeat = decoder.decode(frame("EA 00 03 00 0B 01")) else { return XCTFail() }
        guard case .unknown = decoder.decode(frame("EA 00 03 00 1F 03")) else { return XCTFail() }
    }
}
