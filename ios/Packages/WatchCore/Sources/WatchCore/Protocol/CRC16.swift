import Foundation

/// CRC-16/MODBUS (reflected poly 0x8005, init 0xFFFF, no final XOR).
/// Used by the file-transfer frames (research/protocol.md §3.5). Check value for "123456789" is 0x4B37.
public enum CRC16 {
    private static let table: [UInt16] = (0..<256).map { i in
        var c = UInt16(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (c >> 1) ^ 0xA001 : c >> 1 }
        return c
    }

    public static func modbus<S: Sequence>(_ bytes: S, seed: UInt16 = 0xFFFF) -> UInt16 where S.Element == UInt8 {
        var crc = seed
        for b in bytes { crc = (crc >> 8) ^ table[Int((crc ^ UInt16(b)) & 0xFF)] }
        return crc
    }
}
