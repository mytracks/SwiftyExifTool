import Foundation

/// Builds synthetic TIFF files byte by byte, including deliberately
/// malformed ones. Development only; not part of the library product.
public struct TIFFBuilder: Sendable {
    public enum ByteOrder: Sendable { case little, big }

    /// TIFF field types (TIFF 6.0 section 2; UTF-8 from CIPA DC-008 (Exif 3.0 and later)).
    public enum FieldType: UInt16, Sendable {
        case byte = 1, ascii, short, long, rational, sbyte, undefined
        case sshort, slong, srational, float, double
        case utf8 = 129

        var size: Int {
            switch self {
            case .byte, .ascii, .sbyte, .undefined, .utf8: 1
            case .short, .sshort: 2
            case .long, .slong, .float: 4
            case .rational, .srational, .double: 8
            }
        }
    }

    public struct Rational: Sendable { public var numerator, denominator: UInt32
        public init(_ n: UInt32, _ d: UInt32) { numerator = n; denominator = d } }
    public struct SRational: Sendable { public var numerator, denominator: Int32
        public init(_ n: Int32, _ d: Int32) { numerator = n; denominator = d } }

    /// The value of an entry.
    public enum Payload: Sendable {
        case bytes([UInt8])
        case shorts([UInt16])
        case longs([UInt32])
        case sshorts([Int16])
        case slongs([Int32])
        case rationals([Rational])
        case srationals([SRational])
        case floats([Float])
        case doubles([Double])
        /// A pointer (LONG) to a sub-directory laid out by the builder.
        case directory(IFD)
        /// An array of pointers (LONG) to sub-directories, e.g. SubIFDs.
        case directories([IFD])
        /// The 4-byte value/offset field written verbatim (in file byte order).
        case valueField(UInt32)
    }

    public struct Entry: Sendable {
        public var tag: UInt16
        public var type: UInt16
        public var count: UInt32
        public var payload: Payload

        public init(tag: UInt16, type: UInt16, count: UInt32, payload: Payload) {
            self.tag = tag; self.type = type; self.count = count; self.payload = payload
        }

        public init(_ tag: UInt16, _ type: FieldType, count: UInt32? = nil, _ payload: Payload) {
            self.init(tag: tag, type: type.rawValue, count: count ?? Self.count(of: payload, type: type), payload: payload)
        }

        static func count(of payload: Payload, type: FieldType) -> UInt32 {
            switch payload {
            case .bytes(let v): UInt32(v.count)
            case .shorts(let v): UInt32(v.count)
            case .longs(let v): UInt32(v.count)
            case .sshorts(let v): UInt32(v.count)
            case .slongs(let v): UInt32(v.count)
            case .rationals(let v): UInt32(v.count)
            case .srationals(let v): UInt32(v.count)
            case .floats(let v): UInt32(v.count)
            case .doubles(let v): UInt32(v.count)
            case .directory: 1
            case .directories(let v): UInt32(v.count)
            case .valueField: 1
            }
        }

        // Convenience constructors.
        public static func byte(_ tag: UInt16, _ v: [UInt8]) -> Entry { Entry(tag, .byte, .bytes(v)) }
        public static func undefined(_ tag: UInt16, _ v: [UInt8]) -> Entry { Entry(tag, .undefined, .bytes(v)) }
        public static func sbyte(_ tag: UInt16, _ v: [Int8]) -> Entry { Entry(tag, .sbyte, .bytes(v.map { UInt8(bitPattern: $0) })) }
        /// ASCII string; a terminating NUL is appended unless `terminate` is false.
        public static func ascii(_ tag: UInt16, _ s: String, terminate: Bool = true) -> Entry {
            Entry(tag, .ascii, .bytes(Array(s.utf8) + (terminate ? [0] : [])))
        }
        public static func asciiBytes(_ tag: UInt16, _ v: [UInt8]) -> Entry { Entry(tag, .ascii, .bytes(v)) }
        public static func utf8(_ tag: UInt16, _ s: String) -> Entry { Entry(tag, .utf8, .bytes(Array(s.utf8) + [0])) }
        public static func short(_ tag: UInt16, _ v: UInt16...) -> Entry { Entry(tag, .short, .shorts(v)) }
        public static func shorts(_ tag: UInt16, _ v: [UInt16]) -> Entry { Entry(tag, .short, .shorts(v)) }
        public static func long(_ tag: UInt16, _ v: UInt32...) -> Entry { Entry(tag, .long, .longs(v)) }
        public static func longs(_ tag: UInt16, _ v: [UInt32]) -> Entry { Entry(tag, .long, .longs(v)) }
        public static func sshort(_ tag: UInt16, _ v: Int16...) -> Entry { Entry(tag, .sshort, .sshorts(v)) }
        public static func slong(_ tag: UInt16, _ v: Int32...) -> Entry { Entry(tag, .slong, .slongs(v)) }
        public static func rational(_ tag: UInt16, _ n: UInt32, _ d: UInt32) -> Entry { Entry(tag, .rational, .rationals([Rational(n, d)])) }
        public static func rationals(_ tag: UInt16, _ v: [Rational]) -> Entry { Entry(tag, .rational, .rationals(v)) }
        public static func srational(_ tag: UInt16, _ n: Int32, _ d: Int32) -> Entry { Entry(tag, .srational, .srationals([SRational(n, d)])) }
        public static func srationals(_ tag: UInt16, _ v: [SRational]) -> Entry { Entry(tag, .srational, .srationals(v)) }
        public static func float(_ tag: UInt16, _ v: Float...) -> Entry { Entry(tag, .float, .floats(v)) }
        public static func double(_ tag: UInt16, _ v: Double...) -> Entry { Entry(tag, .double, .doubles(v)) }
        public static func pointer(_ tag: UInt16, _ ifd: IFD) -> Entry { Entry(tag, .long, .directory(ifd)) }
        public static func subIFDs(_ ifds: [IFD]) -> Entry { Entry(0x014A, .long, .directories(ifds)) }
        public static func exif(_ ifd: IFD) -> Entry { pointer(0x8769, ifd) }
        public static func gps(_ ifd: IFD) -> Entry { pointer(0x8825, ifd) }
        public static func interop(_ ifd: IFD) -> Entry { pointer(0xA005, ifd) }
    }

    /// One image file directory.
    public struct IFD: Sendable {
        public var entries: [Entry]
        /// Overrides the next-IFD offset written for this directory.
        public var nextOverride: UInt32?
        public init(_ entries: [Entry], nextOverride: UInt32? = nil) {
            self.entries = entries; self.nextOverride = nextOverride
        }
    }

    /// Where an entry and its value ended up in the file.
    public struct EntryLocation: Sendable, Hashable {
        /// Directory path, e.g. `IFD0`, `IFD1`, `IFD0/8769`, `IFD0/014A[1]`.
        public var directory: String
        public var tag: UInt16
        public var entryOffset: Int
        public var valueOffset: Int
    }

    public struct Output: Sendable {
        public var data: Data
        public var directoryOffsets: [String: Int]
        public var locations: [EntryLocation]

        public func location(_ directory: String, _ tag: UInt16) -> EntryLocation? {
            locations.first { $0.directory == directory && $0.tag == tag }
        }
    }

    public var byteOrder: ByteOrder
    /// The IFD chain: IFD0, IFD1, …
    public var chain: [IFD]
    /// The TIFF version field (42 for TIFF; 43 marks BigTIFF).
    public var version: UInt16 = 42
    /// Overrides the IFD0 offset in the header.
    public var ifd0OffsetOverride: UInt32?
    /// Byte patches applied after layout: (offset, bytes).
    public var patches: [(offset: Int, bytes: [UInt8])] = []
    /// Truncates the output to this length after patches.
    public var truncateTo: Int?
    /// Makes the last IFD of the chain link back to this chain index.
    public var linkLastIFDTo: Int?

    public init(_ byteOrder: ByteOrder = .little, chain: [IFD]) {
        self.byteOrder = byteOrder
        self.chain = chain
    }

    public func build() -> Output {
        var writer = Writer(order: byteOrder)
        writer.bytes(byteOrder == .little ? [0x49, 0x49] : [0x4D, 0x4D])
        writer.u16(version)
        let ifd0Field = writer.count
        writer.u32(0)

        var previousNextField: Int?
        for (index, ifd) in chain.enumerated() {
            let offset = writer.layout(ifd, path: "IFD\(index)")
            if let previousNextField {
                writer.patch32(at: previousNextField, UInt32(offset))
            } else {
                writer.patch32(at: ifd0Field, ifd0OffsetOverride ?? UInt32(offset))
            }
            previousNextField = writer.nextFields["IFD\(index)"]
        }
        if chain.isEmpty, let ifd0OffsetOverride { writer.patch32(at: ifd0Field, ifd0OffsetOverride) }
        if let target = linkLastIFDTo, let last = previousNextField,
           let targetOffset = writer.directoryOffsets["IFD\(target)"] {
            writer.patch32(at: last, UInt32(targetOffset))
        }

        var data = writer.data
        for patch in patches {
            for (i, byte) in patch.bytes.enumerated() where patch.offset + i < data.count {
                data[patch.offset + i] = byte
            }
        }
        if let truncateTo, truncateTo < data.count { data = data.prefix(truncateTo) }
        return Output(data: Data(data), directoryOffsets: writer.directoryOffsets, locations: writer.locations)
    }
}

private struct Writer {
    let order: TIFFBuilder.ByteOrder
    var data = Data()
    var directoryOffsets: [String: Int] = [:]
    var nextFields: [String: Int] = [:]
    var locations: [TIFFBuilder.EntryLocation] = []

    init(order: TIFFBuilder.ByteOrder) { self.order = order }

    var count: Int { data.count }

    mutating func bytes(_ b: [UInt8]) { data.append(contentsOf: b) }
    mutating func u16(_ v: UInt16) { bytes(encode(UInt64(v), size: 2)) }
    mutating func u32(_ v: UInt32) { bytes(encode(UInt64(v), size: 4)) }

    func encode(_ v: UInt64, size: Int) -> [UInt8] {
        let le = (0 ..< size).map { UInt8(truncatingIfNeeded: v >> (8 * UInt64($0))) }
        return order == .little ? le : le.reversed()
    }

    mutating func patch32(at offset: Int, _ v: UInt32) {
        for (i, b) in encode(UInt64(v), size: 4).enumerated() { data[offset + i] = b }
    }

    mutating func align() { if data.count % 2 == 1 { data.append(0) } }

    func encodePayload(_ payload: TIFFBuilder.Payload) -> [UInt8] {
        switch payload {
        case .bytes(let v): v
        case .shorts(let v): v.flatMap { encode(UInt64($0), size: 2) }
        case .longs(let v): v.flatMap { encode(UInt64($0), size: 4) }
        case .sshorts(let v): v.flatMap { encode(UInt64(UInt16(bitPattern: $0)), size: 2) }
        case .slongs(let v): v.flatMap { encode(UInt64(UInt32(bitPattern: $0)), size: 4) }
        case .rationals(let v): v.flatMap { encode(UInt64($0.numerator), size: 4) + encode(UInt64($0.denominator), size: 4) }
        case .srationals(let v): v.flatMap {
            encode(UInt64(UInt32(bitPattern: $0.numerator)), size: 4) + encode(UInt64(UInt32(bitPattern: $0.denominator)), size: 4) }
        case .floats(let v): v.flatMap { encode(UInt64($0.bitPattern), size: 4) }
        case .doubles(let v): v.flatMap { encode($0.bitPattern, size: 8) }
        case .directory, .directories: []
        case .valueField(let v): encode(UInt64(v), size: 4)
        }
    }

    /// Lays out `ifd` at the current end of the data and returns its offset.
    mutating func layout(_ ifd: TIFFBuilder.IFD, path: String) -> Int {
        align()
        let start = data.count
        directoryOffsets[path] = start
        u16(UInt16(truncatingIfNeeded: ifd.entries.count))
        let tableStart = data.count
        data.append(Data(count: ifd.entries.count * 12))
        let nextField = data.count
        nextFields[path] = nextField
        u32(ifd.nextOverride ?? 0)

        var pending: [(field: Int, path: String, ifds: [TIFFBuilder.IFD])] = []
        for (index, entry) in ifd.entries.enumerated() {
            let entryOffset = tableStart + index * 12
            var header = encode(UInt64(entry.tag), size: 2) + encode(UInt64(entry.type), size: 2)
            header += encode(UInt64(entry.count), size: 4)
            for (i, b) in header.enumerated() { data[entryOffset + i] = b }
            let field = entryOffset + 8
            let tagHex = String(format: "%04X", entry.tag)

            switch entry.payload {
            case .directory(let sub):
                pending.append((field, "\(path)/\(tagHex)", [sub]))
                locations.append(.init(directory: path, tag: entry.tag, entryOffset: entryOffset, valueOffset: field))
            case .directories(let subs):
                pending.append((field, "\(path)/\(tagHex)", subs))
                locations.append(.init(directory: path, tag: entry.tag, entryOffset: entryOffset, valueOffset: field))
            case .valueField:
                for (i, b) in encodePayload(entry.payload).enumerated() { data[field + i] = b }
                locations.append(.init(directory: path, tag: entry.tag, entryOffset: entryOffset, valueOffset: field))
            default:
                let value = encodePayload(entry.payload)
                if value.count <= 4 {
                    for (i, b) in value.enumerated() { data[field + i] = b }
                    locations.append(.init(directory: path, tag: entry.tag, entryOffset: entryOffset, valueOffset: field))
                } else {
                    align()
                    let valueOffset = data.count
                    bytes(value)
                    patch32(at: field, UInt32(valueOffset))
                    locations.append(.init(directory: path, tag: entry.tag, entryOffset: entryOffset, valueOffset: valueOffset))
                }
            }
        }

        for item in pending {
            var offsets: [Int] = []
            for (i, sub) in item.ifds.enumerated() {
                let subPath = item.ifds.count == 1 && !item.path.hasSuffix("/014A") ? item.path : "\(item.path)[\(i)]"
                offsets.append(layout(sub, path: subPath))
            }
            if offsets.count == 1 {
                patch32(at: item.field, UInt32(offsets[0]))
            } else {
                align()
                let arrayOffset = data.count
                for o in offsets { u32(UInt32(o)) }
                patch32(at: item.field, UInt32(arrayOffset))
            }
        }
        return start
    }
}
