import Foundation

/// Byte order of multi-byte values.
public enum ByteOrder: Sendable, Hashable {
    /// Least significant byte first (`II`, Intel).
    case littleEndian
    /// Most significant byte first (`MM`, Motorola).
    case bigEndian
}

/// Bounds-checked reading of fixed-size values from a byte source.
///
/// All offsets are absolute positions in the source. Every read verifies the
/// requested range with overflow-checked arithmetic before touching data.
struct BinaryReader {
    let source: any ByteSource
    var byteOrder: ByteOrder
    /// Absolute offset that relative offsets (e.g. TIFF offsets) refer to.
    var baseOffset: Int

    init(source: any ByteSource, byteOrder: ByteOrder = .bigEndian, baseOffset: Int = 0) {
        self.source = source
        self.byteOrder = byteOrder
        self.baseOffset = baseOffset
    }

    var size: Int { source.size }

    /// Converts an offset relative to ``baseOffset`` into an absolute offset,
    /// or `nil` on overflow.
    func absolute(_ relative: UInt32) -> Int? {
        let (value, overflow) = baseOffset.addingReportingOverflow(Int(relative))
        return overflow ? nil : value
    }

    /// Whether `count` bytes at absolute `offset` lie within the source.
    func contains(offset: Int, count: Int) -> Bool {
        source.contains(offset: offset, count: count)
    }

    func bytes(at offset: Int, count: Int) throws(ByteSourceError) -> Data {
        try source.read(offset: offset, count: count)
    }

    func uint8(at offset: Int) throws(ByteSourceError) -> UInt8 {
        let data = try source.read(offset: offset, count: 1)
        return data[data.startIndex]
    }

    func uint16(at offset: Int) throws(ByteSourceError) -> UInt16 {
        UInt16(truncatingIfNeeded: try unsigned(at: offset, size: 2))
    }

    func uint32(at offset: Int) throws(ByteSourceError) -> UInt32 {
        UInt32(truncatingIfNeeded: try unsigned(at: offset, size: 4))
    }

    func uint64(at offset: Int) throws(ByteSourceError) -> UInt64 {
        try unsigned(at: offset, size: 8)
    }

    func int8(at offset: Int) throws(ByteSourceError) -> Int8 {
        Int8(bitPattern: try uint8(at: offset))
    }

    func int16(at offset: Int) throws(ByteSourceError) -> Int16 {
        Int16(bitPattern: try uint16(at: offset))
    }

    func int32(at offset: Int) throws(ByteSourceError) -> Int32 {
        Int32(bitPattern: try uint32(at: offset))
    }

    func float32(at offset: Int) throws(ByteSourceError) -> Float {
        Float(bitPattern: try uint32(at: offset))
    }

    func float64(at offset: Int) throws(ByteSourceError) -> Double {
        Double(bitPattern: try uint64(at: offset))
    }

    private func unsigned(at offset: Int, size: Int) throws(ByteSourceError) -> UInt64 {
        let data = try source.read(offset: offset, count: size)
        return Self.decodeUnsigned(data, byteOrder: byteOrder)
    }

    /// Decodes up to 8 bytes as an unsigned integer in the given byte order.
    static func decodeUnsigned(_ data: Data, byteOrder: ByteOrder) -> UInt64 {
        var value: UInt64 = 0
        switch byteOrder {
        case .bigEndian:
            for byte in data { value = value << 8 | UInt64(byte) }
        case .littleEndian:
            for byte in data.reversed() { value = value << 8 | UInt64(byte) }
        }
        return value
    }
}
