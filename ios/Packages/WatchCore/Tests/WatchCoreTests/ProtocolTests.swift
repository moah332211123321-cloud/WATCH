import XCTest
@testable import WatchCore

final class FrameTests: XCTestCase {
    func testLengthFieldIsTotalMinusThree() {
        let f = Frame.classic([0x71, 0x80])
        XCTAssertEqual(f.bytes.count, 6)
        XCTAssertEqual(Int(f.bytes[1]) << 8 | Int(f.bytes[2]), f.bytes.count - 3)
    }

    func testRoundTrip() {
        let f = Frame.extended([0x1F, 0x03])
        XCTAssertEqual(Frame(bytes: f.bytes), f)
    }

    func testRejectsWrongLengthAndUnknownHeader() {
        XCTAssertNil(Frame(bytes: [0xAB, 0x00, 0x05, 0xFF, 0x71, 0x80]))
        XCTAssertNil(Frame(bytes: [0xA0, 0x00, 0x03, 0xFF, 0x71, 0x80]))
        XCTAssertNil(Frame(bytes: [0xAB, 0x00]))
    }

    func testOffsets() {
        let f = Frame.classic([0x92, 0x80, 0x01])
        XCTAssertEqual(f[offset: 4], 0x92)
        XCTAssertEqual(f[offset: 6], 0x01)
        XCTAssertNil(f[offset: 7])
    }
}

final class ReassemblerTests: XCTestCase {
    let info: [UInt8] = [0xAB, 0x00, 0x04, 0xFF, 0x92, 0x80, 0x01]

    func testSingleChunk() {
        var r = Reassembler()
        XCTAssertEqual(r.feed(info).map(\.bytes), [info])
        XCTAssertFalse(r.isPending)
    }

    func testSplitAcrossNotifications() {
        var r = Reassembler()
        XCTAssertTrue(r.feed(Array(info[0..<3])).isEmpty)
        XCTAssertTrue(r.isPending)
        XCTAssertEqual(r.feed(Array(info[3...])).map(\.bytes), [info])
    }

    func testTwoFramesInOneChunk() {
        var r = Reassembler()
        let hb: [UInt8] = [0xEA, 0x00, 0x03, 0x00, 0x0B, 0x01]
        XCTAssertEqual(r.feed(info + hb).count, 2)
    }

    func testSkipsGarbageBeforeHeader() {
        var r = Reassembler()
        XCTAssertEqual(r.feed([0x00, 0x13] + info).map(\.bytes), [info])
    }

    func testDropsAbsurdLength() {
        var r = Reassembler(maxFrameLength: 100)
        XCTAssertTrue(r.feed([0xAB, 0xFF, 0xFF, 0xFF]).isEmpty)
        XCTAssertEqual(r.feed(info).map(\.bytes), [info])
    }
}

final class RGB565Tests: XCTestCase {
    func testPrimaryColours() {
        let rgba: [UInt8] = [255, 0, 0, 255,  0, 255, 0, 255,  0, 0, 255, 255,  255, 255, 255, 255]
        XCTAssertEqual([UInt8](RGB565.encode(rgba: rgba, width: 4, height: 1)),
                       [0xF8, 0x00, 0x07, 0xE0, 0x00, 0x1F, 0xFF, 0xFF])
        XCTAssertEqual([UInt8](RGB565.encode(rgba: Array(rgba[0..<4]), width: 1, height: 1, bigEndian: false)),
                       [0x00, 0xF8])
    }
}

final class CRC16Tests: XCTestCase {
    func testModbusCheckValue() {
        XCTAssertEqual(CRC16.modbus(Array("123456789".utf8)), 0x4B37)
    }

    func testEmptyIsSeed() {
        XCTAssertEqual(CRC16.modbus([UInt8]()), 0xFFFF)
    }
}
