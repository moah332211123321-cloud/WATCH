import XCTest
@testable import WatchCore

/// Bytes captured from the user's own watch ("UrjwanPlus", firmware 1.02) with Sawar's Bluetooth log
/// on 2026-11-10. These are real packets, not values built from the layouts.
final class RealWatchTests: XCTestCase {
    let utc = TimeZone(identifier: "UTC")!
    lazy var decoder = WatchDecoder(timeZone: utc)

    func frame(_ hex: String) -> Frame { Frame(bytes: hex.split(separator: " ").map { UInt8($0, radix: 16)! })! }

    func date(_ h: Int, _ m: Int) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
        return cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: h, minute: m))!
    }

    func testDeviceInfoMatchesWatchFirmwareAndScreen() {
        guard case let .deviceInfo(info) = decoder.decode(frame("AB 00 11 FF 92 C0 01 02 00 8C 00 01 00 00 00 28 00 E2 09 80"))
        else { return XCTFail() }
        XCTAssertEqual(info.firmwareVersion, "1.02")                                   // the watch's About screen says 1.02
        XCTAssertEqual(info.tableScreen, ScreenInfo(width: 240, height: 288, shape: 2)) // rectangular 240x288
    }

    func testBattery() {
        XCTAssertEqual(decoder.decode(frame("AB 00 05 FF 91 80 00 51")), .battery(81))
    }

    func testDaySummary() {
        guard case let .daySummary(s) = decoder.decode(frame("AB 00 0E FF 51 08 00 06 9C 00 00 33 00 20 00 00 01"))
        else { return XCTFail() }
        XCTAssertEqual(s.steps, 1692)
        XCTAssertEqual(s.kilocalories, 51)
        XCTAssertEqual(s.lightSleepMinutes, 32)
        XCTAssertEqual(s.deepSleepMinutes, 0)
        XCTAssertEqual(s.awakeCount, 1)
    }

    func testTemperatureHistory() {
        guard case let .sample(s) = decoder.decode(frame("AB 00 0B FF 51 13 1A 0B 0A 0C 00 24 04 13")) else { return XCTFail() }
        XCTAssertEqual(s.kind, .temperature)
        XCTAssertEqual(s.value, 36.4, accuracy: 0.001)
        XCTAssertEqual(s.date, date(12, 0))
    }

    func testHeartRateHistory() {
        guard case let .sample(s) = decoder.decode(frame("AB 00 0B FF 51 11 1A 0B 0A 10 2B 4D 4D 11")) else { return XCTFail() }
        XCTAssertEqual(s.kind, .heartRate)
        XCTAssertEqual(s.value, 77)
        XCTAssertEqual(s.date, date(16, 43))
    }

    func testSleepMatchesSummaryLightSleep() {
        guard case let .sleep(seg) = decoder.decode(frame("AB 00 0B FF 52 80 1A 0B 0A 16 06 01 00 20")) else { return XCTFail() }
        XCTAssertEqual(seg.start, date(22, 6))
        XCTAssertEqual(seg.minutes, 32)    // same 32 minutes the day summary reports as light sleep
        XCTAssertEqual(seg.stageCode, 1)
    }

    func testHourlyRecord() {
        guard case let .hourly(h) = decoder.decode(frame("AB 00 16 FF 51 20 1A 0B 0A 0C 00 00 34 00 00 01 5E 61 83 5A 00 00 00 00 00"))
        else { return XCTFail() }
        XCTAssertEqual(h.hourStart, date(11, 0))
        XCTAssertEqual(h.steps, 52)
        XCTAssertEqual(h.kilocalories, 1)
        XCTAssertEqual(h.heartRate, 94)
        XCTAssertEqual(h.bloodOxygen, 97)
        XCTAssertEqual(h.systolic, 131)
        XCTAssertEqual(h.diastolic, 90)
    }

    func testFaceAckFromRealTransfer() {
        // Sawar sent package 31 ("AD 04 00 00 1F …"); the watch asked for 32.
        XCTAssertEqual(decoder.decodeRaw([0xAD, 0x02, 0x00, 0x20, 0x00]), .faceAck(nextIndex: 32))
    }

    func testHighSpeedEcho() {
        guard case .unknown = decoder.decode(frame("AB 00 04 FF 87 80 01")) else { return XCTFail() } // watch echoes high-speed on
    }
}
