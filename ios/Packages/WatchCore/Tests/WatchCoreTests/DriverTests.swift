import XCTest
@testable import WatchCore

/// Records writes and optionally answers them, standing in for CoreBluetooth.
final class FakeTransport: WatchTransport, @unchecked Sendable {
    var writes: [[UInt8]] = []
    var maximumWriteLength = 20
    var responder: (([UInt8]) -> [UInt8]?)?
    weak var driver: WakeupDriver?

    func write(_ data: Data, channel: Channel) async throws {
        let bytes = [UInt8](data)
        writes.append(bytes)
        if let reply = responder?(bytes), let driver {
            Task { await driver.receive(Data(reply), channel: .command) }
        }
    }
}

final class DriverTests: XCTestCase {
    let info: [UInt8] = [0xAB, 0x00, 0x10, 0xFF, 0x92, 0x80, 0x01, 0x05, 0x00, 0x01, 0x2C,
                         0x06, 0x00, 0x00, 0x00, 0x86, 0x00, 0x44, 0x00]

    func testHandshakeSendsTimeOsInfoAndDecodesReply() async throws {
        let t = FakeTransport()
        let d = WakeupDriver(transport: t, family: .generic)
        t.driver = d
        t.responder = { $0.count > 4 && $0[4] == 0x92 ? self.info : nil }
        let result = try await d.handshake()
        XCTAssertEqual(result.firmwareVersion, "1.05")
        XCTAssertEqual(t.writes.first?[4], 0x93)       // time first
        XCTAssertEqual(t.writes[1][4], 0x20)           // then phone OS
        XCTAssertEqual(t.writes[2], [0xAB, 0x00, 0x04, 0xFF, 0x92, 0x80, 0x01])
        let caps = await d.capabilities
        XCTAssertEqual(caps[.weather], .supported)
    }

    func testRequestTimesOut() async {
        let t = FakeTransport()
        let d = WakeupDriver(transport: t, family: .generic)
        do {
            _ = try await d.request(.requestDeviceInfo, timeout: .milliseconds(50)) { _ in true }
            XCTFail("expected timeout")
        } catch {
            XCTAssertEqual(error as? WatchError, .timeout)
        }
    }

    func testDestructiveCommandNeedsConsent() async throws {
        let t = FakeTransport()
        let d = WakeupDriver(transport: t, family: .generic)
        do {
            try await d.perform(.factoryReset, consent: nil)
            XCTFail("expected consentRequired")
        } catch {
            XCTAssertEqual(error as? WatchError, .consentRequired)
        }
        XCTAssertTrue(t.writes.isEmpty)
        try await d.perform(.factoryReset, consent: UserConsent(confirmedPhrase: "RESET"))
        XCTAssertEqual(t.writes, [[0xAB, 0x00, 0x03, 0xFF, 0xFF, 0x80]])
    }

    func testAnswersHeartbeat() async {
        let t = FakeTransport()
        let d = WakeupDriver(transport: t, family: .generic)
        await d.receive(Data([0xEA, 0x00, 0x03, 0x00, 0x0B, 0x01]), channel: .command)
        XCTAssertEqual(t.writes, [[0xEA, 0x00, 0x03, 0x00, 0x0B, 0x02]])
    }

    func testLongFramesAreChunked() async throws {
        let t = FakeTransport()
        t.maximumWriteLength = 20
        let d = WakeupDriver(transport: t, family: .generic)
        try await d.write(Frame.classic(Array(repeating: 0x01, count: 40)))
        XCTAssertEqual(t.writes.map(\.count), [20, 20, 4])
    }

    func testFirmwareNeverFlashed() async {
        let t = FakeTransport()
        for family in DeviceFamily.allCases {
            let d = WakeupDriver(transport: t, family: family)
            do {
                try await d.updateFirmware(file: URL(fileURLWithPath: "/tmp/fw.bin"),
                                           consent: UserConsent(confirmedPhrase: "UPDATE"))
                XCTFail("firmware must not be flashed")
            } catch {
                guard case .protocolUnconfirmed = error as? WatchError else { return XCTFail("\(error)") }
            }
        }
        XCTAssertTrue(t.writes.isEmpty)
    }

    func testFamilyDetection() {
        XCTAssertEqual(DriverFactory.family(forServiceUUIDs: [GATT.commandService, GATT.sifliService]), .sifli)
        XCTAssertEqual(DriverFactory.family(forServiceUUIDs: ["FF12", "FE59"]), .bluetrum)
        XCTAssertEqual(DriverFactory.family(forServiceUUIDs: ["fe59"]), .nordic)
        XCTAssertEqual(DriverFactory.family(forServiceUUIDs: [GATT.commandService]), .generic)
    }
}
