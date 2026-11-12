import Foundation

/// Photo ("album") watch-face transfer, as the reference app does it for non-SiFli watches whose
/// platform type is not 9 or 12 (those use a compressed format we do not produce).
/// Source: `TransferOrder.startSendPic / assemblyImageContent / sendImageContent / sendStyle /
/// sendCustomPuzzle / sendMultipleWatchBitmapNum`, `NormalMTransfer` (flow), `DialAnalyzer` (ack).
///
/// Flow: background count → for each 1024-byte package: info packet (`AD …`), then the package as
/// 124-byte chunks (`AE len seq …`) written in 128-byte pieces → the watch answers `AD …` with the
/// index it wants next (same index = resend) → after the last package: style + puzzle flag.
public enum PhotoFace {
    public static let packageSize = 1024
    public static let chunkSize = 124
    /// The reference app writes the content stream in 128-byte pieces (`setSplitNum(128)`).
    public static let writeSize = 128
    /// Platform types that need the compressed `.par` format (`ParTool`) instead of raw RGB565.
    public static let compressedPlatforms: Set<Int> = [9, 12]

    /// `AB 00 04 FF AD 80 n` — number of background images that follow.
    public static func backgroundCount(_ n: Int) -> Frame { .classic([0xAD, 0x80, UInt8(clamping: n)]) }

    public static func packages(_ pixels: Data) -> [[UInt8]] {
        let bytes = [UInt8](pixels)
        return stride(from: 0, to: bytes.count, by: packageSize).map {
            Array(bytes[$0..<min($0 + packageSize, bytes.count)])
        }
    }

    /// 12 raw bytes: `AD len16 index16 crc16 end fileSize32` (all big-endian), CRC-16/MODBUS of the package.
    public static func infoPacket(package: [UInt8], index: Int, isLast: Bool, fileSize: Int) -> [UInt8] {
        let crc = Int(CRC16.modbus(package))
        return [0xAD, be(package.count >> 8), be(package.count), be(index >> 8), be(index),
                be(crc >> 8), be(crc), isLast ? 1 : 0,
                be(fileSize >> 24), be(fileSize >> 16), be(fileSize >> 8), be(fileSize)]
    }

    /// Package split into `AE (chunkLen+2) seq16 chunk…` pieces, concatenated.
    /// The sequence number starts at `index * (package.count / 124)` — the reference app's numbering,
    /// kept as-is even though the trailing partial chunk overlaps the next package's first number.
    public static func contentStream(package: [UInt8], index: Int) -> [UInt8] {
        var seq = index * (package.count / chunkSize)
        var out: [UInt8] = []
        out.reserveCapacity(package.count + (package.count / chunkSize + 1) * 4)
        for start in stride(from: 0, to: package.count, by: chunkSize) {
            let chunk = package[start..<min(start + chunkSize, package.count)]
            out += [0xAE, UInt8(chunk.count + 2), be(seq >> 8), be(seq)]
            out += chunk
            seq += 1
        }
        return out
    }

    /// `AB 00 07 FF 9C R G B font location` (`TransferOrder.sendStyle`). Location codes 1, 2, 3 are
    /// built into the reference app (`AlbumDialActivity` position list, 1 selected by default). Font
    /// codes come from the maker's server; font 0 drew no time on the user's watch (log 2026-11-10), so 1 is the default.
    public static func style(red: UInt8, green: UInt8, blue: UInt8, font: UInt8 = 1, location: UInt8 = 1) -> Frame {
        .classic([0x9C, red, green, blue, font, location])
    }

    /// `EA 00 09 00 0D 01 R G B font location function` (`TransferOrder.sendStyleNew`): same plus a data
    /// widget the watch draws itself. Font and function codes come from the maker's server in the
    /// reference app, so their meaning on a given watch must be found by trying.
    public static func newStyle(red: UInt8, green: UInt8, blue: UInt8, font: UInt8, location: UInt8, function: UInt8) -> Frame {
        .extended([0x0D, 0x01, red, green, blue, font, location, function])
    }

    public static func frame(for s: PhotoFaceStyle) -> Frame {
        if let f = s.function {
            return newStyle(red: s.red, green: s.green, blue: s.blue, font: s.font, location: s.location, function: f)
        }
        return style(red: s.red, green: s.green, blue: s.blue, font: s.font, location: s.location)
    }

    /// `EA 00 04 00 08 00 v` — is this a puzzle face.
    public static func puzzleFlag(_ on: Bool) -> Frame { .extended([0x08, 0x00, on ? 1 : 0]) }

    /// The watch's answer `AD x i1 i2 …`. The reference app reads the next index as the decimal digits
    /// of byte 2 followed by byte 3 (`"\(b2)\(b3)"`), not as a 16-bit number. Kept identical.
    public static func nextIndex(fromAck bytes: [UInt8]) -> Int? {
        guard bytes.count >= 4, bytes[0] == 0xAD else { return nil }
        return Int("\(bytes[2])\(bytes[3])")
    }

    private static func be(_ v: Int) -> UInt8 { UInt8(truncatingIfNeeded: v) }
}

/// Time colour + layout of a photo face. `function == nil` sends the classic style command.
public struct PhotoFaceStyle: Equatable, Sendable {
    public var red: UInt8, green: UInt8, blue: UInt8
    public var font: UInt8
    public var location: UInt8
    public var function: UInt8?
    public init(red: UInt8, green: UInt8, blue: UInt8, font: UInt8 = 1, location: UInt8 = 1, function: UInt8? = nil) {
        self.red = red; self.green = green; self.blue = blue
        self.font = font; self.location = location; self.function = function
    }
}

/// Screen size by the device-info `byte18` code (`DeviceInfoModel$Byte18Model`). Used only when the
/// watch did not answer the screen-info request (`EA 14 01`), as the reference app does.
public enum ScreenTable {
    public static func screen(code: UInt8) -> ScreenInfo? {
        switch code {
        case 1, 2: return ScreenInfo(width: 240, height: 240, shape: 1)
        case 3, 4: return ScreenInfo(width: 80, height: 160, shape: 2)
        case 5, 6: return ScreenInfo(width: 135, height: 240, shape: 2)
        case 7, 8: return ScreenInfo(width: 240, height: 240, shape: 0)
        case 9, 10: return ScreenInfo(width: 240, height: 288, shape: 2)
        case 11, 12: return ScreenInfo(width: 240, height: 283, shape: 2)
        case 13, 14, 35, 36: return ScreenInfo(width: 360, height: 360, shape: 0)
        case 15, 16: return ScreenInfo(width: 320, height: 380, shape: 2)
        case 17, 18: return ScreenInfo(width: 320, height: 385, shape: 2)
        case 19, 20: return ScreenInfo(width: 320, height: 360, shape: 2)
        case 21, 22: return ScreenInfo(width: 240, height: 296, shape: 2)
        case 23, 24: return ScreenInfo(width: 412, height: 412, shape: 0)
        case 25, 32: return ScreenInfo(width: 410, height: 494, shape: 2)
        case 33, 34: return ScreenInfo(width: 466, height: 466, shape: 0)
        case 38: return ScreenInfo(width: 480, height: 480, shape: 0)
        default: return nil
        }
    }
}
