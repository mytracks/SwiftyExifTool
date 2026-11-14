import Foundation

/// Walks the TIFF structure (TIFF 6.0 section 2) starting at the reader's
/// base offset and produces tags, directories and warnings.
///
/// Safety properties:
/// - every read is bounds-checked by ``BinaryReader``;
/// - value sizes are computed with overflow checks and compared with the
///   file size before any allocation;
/// - each directory offset is read at most once (cycle detection);
/// - the number of directories and the nesting depth are bounded by
///   ``ReadingLimits``.
struct TIFFParser {
    /// Sub-directory pointer tags of the main table.
    enum Pointer {
        static let exif: UInt16 = 0x8769      // CIPA DC-008-2026, 4.6.3.1.1
        static let gps: UInt16 = 0x8825       // CIPA DC-008-2026, 4.6.3.2.1
        static let interop: UInt16 = 0xA005   // CIPA DC-008-2026, 4.6.3.3.1
        static let subIFDs: UInt16 = 0x014A   // Adobe PageMaker 6.0 TIFF Technical Notes, TN 1 "TIFF Trees"
    }

    private(set) var reader: BinaryReader
    let limits: ReadingLimits

    private(set) var tags: [Tag] = []
    private(set) var directories: [Directory] = []
    private(set) var warnings: [ReadWarning] = []
    private var visited: Set<Int> = []
    private var subIFDCount = 0
    private var directoryLimitReported = false

    init(reader: BinaryReader, limits: ReadingLimits) {
        self.reader = reader
        self.limits = limits
    }

    /// Parses the header at the base offset and the whole IFD chain.
    mutating func parse() {
        let base = reader.baseOffset
        guard let ifd0 = try? reader.uint32(at: base + 4) else {
            warn("Truncated TIFF header", offset: base)
            return
        }
        var next = ifd0
        var index = 0
        while next != 0 {
            let group = TagGroup.ifd(index)
            guard let offset = reader.absolute(next) else {
                warn("Bad \(group) directory", group: group)
                return
            }
            if visited.contains(offset) {
                warn("\(group) pointer references a previously read directory; not followed", group: group, offset: offset)
                return
            }
            guard checkDirectoryLimit(group: group) else { return }
            guard let following = readDirectory(at: offset, group: group, table: .main, depth: 0) else { return }
            next = following
            index += 1
        }
    }

    private mutating func warn(_ message: String, group: TagGroup? = nil, offset: Int? = nil) {
        warnings.append(ReadWarning(message, group: group, offset: offset))
    }

    private mutating func checkDirectoryLimit(group: TagGroup) -> Bool {
        if directories.count < limits.maxDirectories { return true }
        if !directoryLimitReported {
            directoryLimitReported = true
            warn("Directory limit of \(limits.maxDirectories) reached; \(group) and further directories not read", group: group)
        }
        return false
    }

    /// Reads one directory and returns its next-IFD offset, or `nil` when the
    /// directory could not be read.
    private mutating func readDirectory(at offset: Int, group: TagGroup, table: TagTable, depth: Int) -> UInt32? {
        guard let count = try? reader.uint16(at: offset) else {
            warn("Bad \(group) directory", group: group, offset: offset)
            return nil
        }
        let tableLength = 2 + Int(count) * 12
        guard reader.contains(offset: offset, count: tableLength) else {
            warn("Bad \(group) directory", group: group, offset: offset)
            return nil
        }
        visited.insert(offset)

        let nextField = offset + tableLength
        let next: UInt32?
        if let value = try? reader.uint32(at: nextField) {
            next = value
        } else {
            next = nil
            warn("\(group) has no next-IFD offset", group: group, offset: nextField)
        }
        directories.append(Directory(group: group, offset: offset, entryCount: Int(count), nextIFDOffset: next))

        for index in 0 ..< Int(count) {
            readEntry(at: offset + 2 + index * 12, index: index, group: group, table: table, depth: depth)
        }
        return next ?? 0
    }

    private mutating func readEntry(at entryOffset: Int, index: Int, group: TagGroup, table: TagTable, depth: Int) {
        // The entry table was bounds-checked by readDirectory.
        guard let id = try? reader.uint16(at: entryOffset),
              let rawType = try? reader.uint16(at: entryOffset + 2),
              let count = try? reader.uint32(at: entryOffset + 4)
        else { return }
        let hexID = String(format: "0x%04x", id)

        guard let type = FieldType(rawValue: rawType) else {
            warn("Unknown field type \(rawType) for \(group) entry \(index), tag \(hexID); entry skipped", group: group, offset: entryOffset)
            return
        }

        let (size, overflow) = Int(count).multipliedReportingOverflow(by: type.size)
        let valueOffset: Int
        if overflow {
            warn("Value size overflow for \(group) tag \(hexID)", group: group, offset: entryOffset)
            return
        } else if size <= 4 {
            valueOffset = entryOffset + 8
        } else {
            guard let field = try? reader.uint32(at: entryOffset + 8), let absolute = reader.absolute(field) else { return }
            valueOffset = absolute
        }

        if table == .main, let subGroup = subdirectoryGroup(for: id), type == .long || type == .short {
            followPointers(id: id, type: type, count: count, valueOffset: valueOffset, size: size,
                           group: subGroup, parent: group, depth: depth)
            return
        }

        guard reader.contains(offset: valueOffset, count: size) else {
            warn("Value of \(group) tag \(hexID) (\(size) bytes at offset \(valueOffset)) extends beyond the end of the file; tag skipped",
                 group: group, offset: entryOffset)
            return
        }

        let contents: StoredValue.Contents
        if size > limits.maxLoadedValueSize {
            contents = .notLoaded
        } else {
            guard let decoded = try? decode(type: type, count: Int(count), at: valueOffset) else { return }
            contents = decoded
        }
        let stored = StoredValue(fieldType: type, count: count, contents: contents)
        let location = ValueLocation(entryOffset: entryOffset, valueOffset: valueOffset, length: size)
        tags.append(TagFactory.makeTag(table: table, group: group, id: id, stored: stored, location: location,
                                       byteOrder: reader.byteOrder))
    }

    /// The group a sub-directory pointer leads to; `SubIFDs` are numbered later.
    private func subdirectoryGroup(for id: UInt16) -> TagGroup? {
        switch id {
        case Pointer.exif: .exifIFD
        case Pointer.gps: .gps
        case Pointer.interop: .interopIFD
        case Pointer.subIFDs: "SubIFD"
        default: nil
        }
    }

    private mutating func followPointers(id: UInt16, type: FieldType, count: UInt32, valueOffset: Int, size: Int,
                                         group: TagGroup, parent: TagGroup, depth: Int) {
        guard reader.contains(offset: valueOffset, count: size) else {
            warn("Bad \(group) pointer in \(parent)", group: parent, offset: valueOffset)
            return
        }
        // A pointer array can never hold more directories than the limit allows.
        let pointerCount = min(Int(count), limits.maxDirectories)
        for k in 0 ..< pointerCount {
            let pointer: UInt32
            if type == .short {
                guard let value = try? reader.uint16(at: valueOffset + k * 2) else { return }
                pointer = UInt32(value)
            } else {
                guard let value = try? reader.uint32(at: valueOffset + k * 4) else { return }
                pointer = value
            }
            let subGroup: TagGroup
            let table: TagTable
            if id == Pointer.subIFDs {
                subGroup = .subIFD(subIFDCount)
                subIFDCount += 1
                table = .main
            } else {
                subGroup = group
                table = id == Pointer.gps ? .gps : .main
            }
            guard depth + 1 <= limits.maxDepth else {
                warn("Nesting depth limit of \(limits.maxDepth) reached; \(subGroup) not read", group: parent)
                return
            }
            guard let offset = reader.absolute(pointer), pointer != 0 else {
                warn("Bad \(subGroup) directory", group: subGroup)
                continue
            }
            if visited.contains(offset) {
                warn("\(subGroup) pointer references a previously read directory; not followed", group: subGroup, offset: offset)
                continue
            }
            guard checkDirectoryLimit(group: subGroup) else { return }
            _ = readDirectory(at: offset, group: subGroup, table: table, depth: depth + 1)
        }
    }

    private func decode(type: FieldType, count: Int, at offset: Int) throws(ByteSourceError) -> StoredValue.Contents {
        let data = try reader.bytes(at: offset, count: count * type.size)
        let bytes = [UInt8](data)
        let order = reader.byteOrder
        func unsigned(_ index: Int, _ width: Int) -> UInt64 {
            var value: UInt64 = 0
            for k in 0 ..< width {
                let byte = UInt64(bytes[index + (order == .bigEndian ? k : width - 1 - k)])
                value = value << 8 | byte
            }
            return value
        }
        switch type {
        case .byte, .undefined:
            return .bytes(data)
        case .ascii, .utf8:
            return .text(data)
        case .short:
            return .unsigned((0 ..< count).map { UInt32(unsigned($0 * 2, 2)) })
        case .long:
            return .unsigned((0 ..< count).map { UInt32(unsigned($0 * 4, 4)) })
        case .sbyte:
            return .signed(bytes.map { Int32(Int8(bitPattern: $0)) })
        case .sshort:
            return .signed((0 ..< count).map { Int32(Int16(bitPattern: UInt16(unsigned($0 * 2, 2)))) })
        case .slong:
            return .signed((0 ..< count).map { Int32(bitPattern: UInt32(unsigned($0 * 4, 4))) })
        case .rational:
            return .rationals((0 ..< count).map { Rational(UInt32(unsigned($0 * 8, 4)), UInt32(unsigned($0 * 8 + 4, 4))) })
        case .srational:
            return .signedRationals((0 ..< count).map {
                SignedRational(Int32(bitPattern: UInt32(unsigned($0 * 8, 4))), Int32(bitPattern: UInt32(unsigned($0 * 8 + 4, 4))))
            })
        case .float:
            return .floats((0 ..< count).map { Float(bitPattern: UInt32(unsigned($0 * 4, 4))) })
        case .double:
            return .doubles((0 ..< count).map { Double(bitPattern: unsigned($0 * 8, 8)) })
        }
    }
}
