import Foundation

/// RGBA8888 → RGB565 (2 bytes per pixel). The reference app converts face images to 16-bit pixels
/// before sending (research/watchface-format.md §2). Byte order on the wire is unconfirmed; big-endian
/// is used here and can be switched once a capture shows the real order.
public enum RGB565 {
    public static func encode(rgba: [UInt8], width: Int, height: Int, bigEndian: Bool = true) -> Data {
        precondition(rgba.count == width * height * 4, "rgba size mismatch")
        var out = Data(capacity: width * height * 2)
        var i = 0
        while i < rgba.count {
            let r = UInt16(rgba[i]) >> 3, g = UInt16(rgba[i + 1]) >> 2, b = UInt16(rgba[i + 2]) >> 3
            let v = (r << 11) | (g << 5) | b
            if bigEndian { out.append(UInt8(v >> 8)); out.append(UInt8(v & 0xFF)) }
            else { out.append(UInt8(v & 0xFF)); out.append(UInt8(v >> 8)) }
            i += 4
        }
        return out
    }
}
