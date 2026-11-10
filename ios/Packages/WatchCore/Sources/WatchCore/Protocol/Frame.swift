import Foundation

/// The two frame families of the watch protocol (research/protocol.md §3).
public enum FrameKind: UInt8, Sendable {
    /// Classic command set: `AB len_hi len_lo FF cmd …`
    case classic = 0xAB
    /// Newer command set: `EA len_hi len_lo marker group sub …`
    case extended = 0xEA
}

/// One protocol frame. `body` starts with the command byte (classic) or group byte (extended).
///
/// Wire layout: `kind, length (UInt16 big-endian = total - 3), marker, body…`.
/// Status: derived from static analysis, not yet confirmed on a real watch.
public struct Frame: Equatable, Sendable {
    public var kind: FrameKind
    /// Byte 3. `0xFF` for classic frames; `0x00` for most extended frames (meaning unknown).
    public var marker: UInt8
    public var body: [UInt8]

    public init(kind: FrameKind, marker: UInt8? = nil, body: [UInt8]) {
        self.kind = kind
        self.marker = marker ?? (kind == .classic ? 0xFF : 0x00)
        self.body = body
    }

    public static func classic(_ body: [UInt8]) -> Frame { Frame(kind: .classic, body: body) }
    public static func extended(_ body: [UInt8], marker: UInt8 = 0x00) -> Frame {
        Frame(kind: .extended, marker: marker, body: body)
    }

    /// Command (classic) or group (extended).
    public var command: UInt8? { body.first }
    /// Byte 5 of the frame: sub-command (extended) or flag / first parameter (classic).
    public var sub: UInt8? { body.count > 1 ? body[1] : nil }
    /// Bytes after command and sub.
    public var payload: ArraySlice<UInt8> { body.dropFirst(2) }

    /// Full frame bytes ready to write.
    public var bytes: [UInt8] {
        let length = body.count + 1 // marker + body
        precondition(length <= 0xFFFF, "frame too long")
        return [kind.rawValue, UInt8(length >> 8), UInt8(length & 0xFF), marker] + body
    }

    public var data: Data { Data(bytes) }

    /// Byte at absolute frame offset (0 = header byte), as the research docs number them.
    public subscript(offset offset: Int) -> UInt8? {
        let all = bytes
        return offset >= 0 && offset < all.count ? all[offset] : nil
    }

    /// Parses one complete frame. Returns nil when the header is unknown or the length does not match.
    public init?(bytes: [UInt8]) {
        guard bytes.count >= 4, let kind = FrameKind(rawValue: bytes[0]) else { return nil }
        let length = Int(bytes[1]) << 8 | Int(bytes[2])
        guard length + 3 == bytes.count else { return nil }
        self.kind = kind
        self.marker = bytes[3]
        self.body = Array(bytes[4...])
    }
}

extension Array where Element == UInt8 {
    public var hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
