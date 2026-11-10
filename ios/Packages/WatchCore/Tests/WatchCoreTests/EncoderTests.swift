import XCTest
@testable import WatchCore

/// Golden bytes come from the reference app's static byte templates (research/evidence/E1-commands.tsv).
/// They are NOT yet confirmed against a real watch; Phase-2 captures will replace or confirm them.
final class EncoderTests: XCTestCase {
    let utc = TimeZone(identifier: "UTC")!

    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    func assertBytes(_ command: Command, _ hex: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(command.frame.bytes.hex, hex, file: file, line: line)
    }

    func testConstantCommandsMatchTemplates() {
        assertBytes(.findWatch, "AB 00 03 FF 71 80")
        assertBytes(.requestDeviceInfo, "AB 00 04 FF 92 80 01")
        assertBytes(.requestSerialNumber, "AB 00 03 FF AA 80")
        assertBytes(.phoneSystem, "AB 00 05 FF 20 80 01 02")
        assertBytes(.clearData, "AB 00 04 FF 23 80 00")
        assertBytes(.factoryReset, "AB 00 03 FF FF 80")
        assertBytes(.heartbeatReply, "EA 00 03 00 0B 02")
        assertBytes(.requestScreenInfo, "EA 00 03 00 14 01")
    }

    func testSwitchCommands() {
        assertBytes(.raiseToWake(on: true), "AB 00 04 FF 77 80 01")
        assertBytes(.hourlyMeasurement(on: false), "AB 00 04 FF 78 80 00")
        assertBytes(.shakeToTakePhoto(on: true), "AB 00 04 FF 79 80 01")
        assertBytes(.twelveHourClock(true), "AB 00 04 FF 7C 80 01")
        assertBytes(.temperatureUnitFahrenheit(false), "AB 00 04 FF EF 80 00")
        assertBytes(.language(code: 3), "AB 00 04 FF 7B 80 03")
        assertBytes(.measure(.heartRate, on: true), "AB 00 04 FF 31 09 01")
    }

    func testTimeSync() {
        assertBytes(.setTime(date(2026, 11, 10, 18, 35, 7), utc), "AB 00 0B FF 93 80 00 07 EA 0B 0A 12 23 07")
    }

    func testTimeSyncUsesGivenZone() {
        let cairo = TimeZone(identifier: "Africa/Cairo")!
        let local = Command.setTime(date(2026, 1, 15, 10, 0, 0), cairo).frame.bytes
        XCTAssertEqual(local[11], 12) // 10:00 UTC = 12:00 in Cairo (UTC+2 in January)
    }

    func testSyncRequests() {
        assertBytes(.syncSleep(day: date(2026, 11, 10), utc), "AB 00 07 FF 52 80 00 1A 0B 0A")
        assertBytes(.syncHistory(since: date(2026, 11, 10, 8, 5), utc),
                    "AB 00 0E FF 51 80 00 1A 0B 0A 00 00 1A 0B 0A 08 05")
        let first = Command.syncHistory(since: nil, utc).frame.bytes
        XCTAssertEqual(first.count, 17)
        XCTAssertEqual(Array(first[10...]), [0, 0, 0, 0, 0, 0, 0])
    }

    func testReminders() {
        let day = TimeWindow(startHour: 9, startMinute: 0, endHour: 18, endMinute: 0)
        assertBytes(.sedentaryReminder(on: true, window: day, intervalMinutes: 60), "AB 00 09 FF 75 80 01 09 00 12 00 3C")
        assertBytes(.drinkWaterReminder(on: true, window: day, intervalMinutes: 60), "AB 00 09 FF 53 80 01 09 00 12 00 3C")
        let night = TimeWindow(startHour: 22, startMinute: 0, endHour: 7, endMinute: 0)
        assertBytes(.doNotDisturb(on: true, window: night), "AB 00 08 FF 76 80 01 16 00 07 00")
    }

    func testAlarm() {
        let weekdays: Weekdays = [.monday, .tuesday, .wednesday, .thursday, .friday]
        assertBytes(.alarm(index: 0, enabled: true, hour: 7, minute: 30, repeats: weekdays, flags: 0),
                    "AB 00 09 FF 73 80 00 01 07 1E 1F 00")
    }

    func testIntervalIsClampedToOneByte() {
        let day = TimeWindow(startHour: 9, startMinute: 0, endHour: 18, endMinute: 0)
        let bytes = Command.sedentaryReminder(on: true, window: day, intervalMinutes: 1000).frame.bytes
        XCTAssertEqual(bytes.last, 0xFF)
    }

    func testDestructiveFlags() {
        XCTAssertTrue(Command.factoryReset.isDestructive)
        XCTAssertTrue(Command.clearData.isDestructive)
        XCTAssertFalse(Command.findWatch.isDestructive)
    }
}
