import XCTest
@testable import WatchCore

/// Layouts from the reference app's source (TransferOrder / NormalMTransfer / DialAnalyzer).
/// Expected bytes were computed independently (Python) from those layouts. Not yet seen on a real watch.
final class PhotoFaceTests: XCTestCase {
    let package = (0..<250).map { UInt8($0) }

    func testInfoPacket() {
        let info = PhotoFace.infoPacket(package: package, index: 3, isLast: true, fileSize: 1250)
        XCTAssertEqual(info.hex, "AD 00 FA 00 03 CD C0 01 00 00 04 E2")
    }

    func testContentStreamChunksAndSequence() {
        let s = PhotoFace.contentStream(package: package, index: 3)
        XCTAssertEqual(s.count, 262)
        XCTAssertEqual(Array(s[0..<6]).hex, "AE 7E 00 06 00 01")      // seq starts at 3 * (250 / 124) = 6
        XCTAssertEqual(Array(s[128..<132]).hex, "AE 7E 00 07")
        XCTAssertEqual(Array(s[256..<262]).hex, "AE 04 00 08 F8 F9")  // 2-byte tail chunk
    }

    func testFullPackageIsOneHundredTwentyEightBytePieces() {
        let s = PhotoFace.contentStream(package: Array(repeating: 0, count: 1024), index: 0)
        XCTAssertEqual(s.count, 8 * 128 + 4 + 32)
    }

    func testPackagesSplitAt1024() {
        XCTAssertEqual(PhotoFace.packages(Data(count: 2500)).map(\.count), [1024, 1024, 452])
    }

    func testCommandFrames() {
        XCTAssertEqual(PhotoFace.backgroundCount(1).bytes.hex, "AB 00 04 FF AD 80 01")
        XCTAssertEqual(PhotoFace.style(red: 255, green: 128, blue: 0).bytes.hex, "AB 00 07 FF 9C FF 80 00 01 01")
        XCTAssertEqual(PhotoFace.newStyle(red: 1, green: 2, blue: 3, font: 4, location: 2, function: 6).bytes.hex,
                       "EA 00 09 00 0D 01 01 02 03 04 02 06")
        XCTAssertEqual(PhotoFace.frame(for: PhotoFaceStyle(red: 9, green: 9, blue: 9, function: 3)).bytes.hex,
                       "EA 00 09 00 0D 01 09 09 09 01 01 03")
        XCTAssertEqual(PhotoFace.puzzleFlag(false).bytes.hex, "EA 00 04 00 08 00 00")
    }

    func testAckIndexIsDecimalConcatenation() {
        XCTAssertEqual(PhotoFace.nextIndex(fromAck: [0xAD, 0x00, 0x00, 0x05]), 5)
        XCTAssertEqual(PhotoFace.nextIndex(fromAck: [0xAD, 0x00, 0x01, 0x02, 0x00, 0x00]), 12) // "1" + "2", as the reference app
        XCTAssertNil(PhotoFace.nextIndex(fromAck: [0xAB, 0x00, 0x00, 0x05]))
    }

    func testScreenTable() {
        XCTAssertEqual(ScreenTable.screen(code: 7), ScreenInfo(width: 240, height: 240, shape: 0))
        XCTAssertEqual(ScreenTable.screen(code: 33), ScreenInfo(width: 466, height: 466, shape: 0))
        XCTAssertEqual(ScreenTable.screen(code: 25), ScreenInfo(width: 410, height: 494, shape: 2))
        XCTAssertNil(ScreenTable.screen(code: 0))
    }
}

final class NewDecoderTests: XCTestCase {
    let decoder = WatchDecoder(timeZone: TimeZone(identifier: "UTC")!)

    func frame(_ hex: String) -> Frame { Frame(bytes: hex.split(separator: " ").map { UInt8($0, radix: 16)! })! }

    func testPlatformReply() {
        guard case let .platform(p) = decoder.decode(frame("AB 00 08 FF 20 80 0C 00 20 03 02")) else { return XCTFail() }
        XCTAssertEqual(p.platform, 12)
        XCTAssertEqual(p.flags, 0x20)
        XCTAssertEqual(p.deviceType, 3)
        XCTAssertEqual(p.otaType, 2)
    }

    func testScreenReply() {
        guard case let .screen(s) = decoder.decode(frame("EA 00 08 00 14 01 01 D2 01 D2 00")) else { return XCTFail() }
        XCTAssertEqual(s, ScreenInfo(width: 466, height: 466, shape: 0))
    }

    func testSportRecord() {
        // type 7, 2026-11-10 07:30, 1800 s, 3000 steps, 150 kcal, 2 km + 50*10 m, avg HR 120
        guard case let .sport(r) = decoder.decode(frame("AB 00 11 FF B7 07 1A 0B 0A 07 1E 07 08 0B B8 00 96 02 32 78"))
        else { return XCTFail() }
        XCTAssertEqual(r.type, 7)
        XCTAssertEqual(r.durationSeconds, 1800)
        XCTAssertEqual(r.steps, 3000)
        XCTAssertEqual(r.kilocalories, 150)
        XCTAssertEqual(r.distanceMeters, 2500)
        XCTAssertEqual(r.averageHeartRate, 120)
    }

    func testRawAndAck() {
        XCTAssertEqual(decoder.decodeRaw([0xAD, 0x00, 0x00, 0x01]), .faceAck(nextIndex: 1))
        XCTAssertEqual(decoder.decodeRaw([0xB0, 0x01]), .raw([0xB0, 0x01]))
    }
}

final class PhotoFaceDriverTests: XCTestCase {
    func testInstallSendsPackagesFollowsAcksThenStyle() async throws {
        let t = FakeTransport()
        t.maximumWriteLength = 182
        let d = WakeupDriver(transport: t, family: .generic)
        t.driver = d
        await d.receive(Data([0xEA, 0x00, 0x08, 0x00, 0x14, 0x01, 0x00, 0x20, 0x00, 0x20, 0x00]), channel: .command) // 32x32
        var acks = 0
        t.responder = { bytes in
            // Answer after the last (short) content piece of each package: 1024 B → 8 × 128 + one 36-byte piece.
            guard bytes.count > 12, bytes.count < 128 else { return nil }
            acks += 1
            return [0xAD, 0x00, 0x00, UInt8(acks)]
        }
        let pixels = Data(repeating: 0x11, count: 32 * 32 * 2)
        try await d.installPhotoFace(pixels: pixels, style: PhotoFaceStyle(red: 255, green: 255, blue: 255, function: 5),
                                     consent: UserConsent(confirmedPhrase: "TRY")) { _ in }
        XCTAssertEqual(acks, 2)
        XCTAssertEqual(t.writes.first, [0xAB, 0x00, 0x04, 0xFF, 0x87, 0x80, 0x01])   // high speed on
        XCTAssertEqual(t.writes[1], [0xAB, 0x00, 0x04, 0xFF, 0xAD, 0x80, 0x01])
        XCTAssertEqual(t.writes[2].first, 0xAD)            // info packet of package 0
        XCTAssertEqual(t.writes[2].count, 12)
        XCTAssertEqual(t.writes[t.writes.count - 3], [0xAB, 0x00, 0x07, 0xFF, 0x9C, 0xFF, 0xFF, 0xFF, 0x01, 0x01])
        XCTAssertEqual(t.writes[t.writes.count - 2], [0xEA, 0x00, 0x04, 0x00, 0x08, 0x00, 0x00])
        XCTAssertEqual(t.writes.last, [0xAB, 0x00, 0x04, 0xFF, 0x87, 0x80, 0x00])     // high speed off
    }

    func testRefusesWithoutScreenOrForCompressedPlatform() async {
        let t = FakeTransport()
        t.maximumWriteLength = 182
        let d = WakeupDriver(transport: t, family: .generic)
        do {
            try await d.installPhotoFace(pixels: Data(count: 8), style: PhotoFaceStyle(red: 0, green: 0, blue: 0), consent: UserConsent(confirmedPhrase: "TRY")) { _ in }
            XCTFail("must refuse without screen size")
        } catch {
            guard case .protocolUnconfirmed = error as? WatchError else { return XCTFail("\(error)") }
        }
        await d.receive(Data([0xAB, 0x00, 0x08, 0xFF, 0x20, 0x80, 0x09, 0x00, 0x00, 0x00, 0x00]), channel: .command)
        await d.receive(Data([0xEA, 0x00, 0x08, 0x00, 0x14, 0x01, 0x00, 0x02, 0x00, 0x02, 0x00]), channel: .command)
        do {
            try await d.installPhotoFace(pixels: Data(count: 8), style: PhotoFaceStyle(red: 0, green: 0, blue: 0), consent: UserConsent(confirmedPhrase: "TRY")) { _ in }
            XCTFail("platform 9 needs the compressed format")
        } catch {
            guard case .protocolUnconfirmed = error as? WatchError else { return XCTFail("\(error)") }
        }
        XCTAssertTrue(t.writes.isEmpty)
    }

    func testSiFliRefused() async {
        let d = WakeupDriver(transport: FakeTransport(), family: .sifli)
        do {
            try await d.installPhotoFace(pixels: Data(), style: PhotoFaceStyle(red: 0, green: 0, blue: 0), consent: UserConsent(confirmedPhrase: "TRY")) { _ in }
            XCTFail()
        } catch {
            guard case .protocolUnconfirmed = error as? WatchError else { return XCTFail("\(error)") }
        }
    }
}
