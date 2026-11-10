import Foundation

/// Joins notification chunks into complete frames (research/protocol.md §3.3).
///
/// Expected total = `((b1 << 8) | b2) + 3`. Chunks are appended until the total is reached.
/// Unlike the reference app this also splits several frames that arrive in one notification.
public struct Reassembler: Sendable {
    private var buffer: [UInt8] = []
    /// Largest frame accepted before the buffer is dropped (guards against garbage lengths).
    public var maxFrameLength: Int

    public init(maxFrameLength: Int = 64 * 1024) {
        self.maxFrameLength = maxFrameLength
    }

    public var isPending: Bool { !buffer.isEmpty }

    public mutating func reset() { buffer.removeAll() }

    /// Feed one notification; returns every frame completed by it.
    public mutating func feed(_ chunk: [UInt8]) -> [Frame] {
        buffer += chunk
        var frames: [Frame] = []
        while true {
            // Resynchronise on a known header byte.
            if let first = buffer.first, FrameKind(rawValue: first) == nil {
                if let next = buffer.firstIndex(where: { FrameKind(rawValue: $0) != nil }) {
                    buffer.removeFirst(next)
                } else {
                    buffer.removeAll()
                    return frames
                }
            }
            guard buffer.count >= 3 else { return frames }
            let total = (Int(buffer[1]) << 8 | Int(buffer[2])) + 3
            guard total >= 4, total <= maxFrameLength else {
                buffer.removeFirst() // bad length: skip this header byte and resync
                continue
            }
            guard buffer.count >= total else { return frames }
            if let frame = Frame(bytes: Array(buffer[0..<total])) { frames.append(frame) }
            buffer.removeFirst(total)
        }
    }
}
