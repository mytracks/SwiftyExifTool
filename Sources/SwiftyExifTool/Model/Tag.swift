import Foundation

/// One metadata item.
///
/// Each tag exposes three levels of its value:
/// - ``stored``: the field as stored in the file, lossless;
/// - ``value``: the value as `exiftool -n` reports it;
/// - ``displayText``: the text `exiftool` reports by default.
public struct Tag: Sendable, Hashable {
    /// The group, e.g. `IFD0`, `ExifIFD` or `File`.
    public let group: TagGroup
    /// The tag name, e.g. `Orientation`.
    public let name: String
    /// The numeric tag ID; `nil` for tags not stored in a directory (`File` group).
    public let id: UInt16?
    /// Whether the library has no definition for this tag ID.
    public let isUnknown: Bool
    /// The stored field; `nil` for tags not stored in a directory.
    public let stored: StoredValue?
    /// The value as `exiftool -n` reports it.
    public let value: TagValue
    /// The text `exiftool` reports by default.
    public let displayText: String
    /// Where the entry and its value are in the file.
    public let location: ValueLocation?

    /// Creates a tag. Normally obtained from ``MetadataReader``.
    public init(group: TagGroup, name: String, id: UInt16?, isUnknown: Bool, stored: StoredValue?,
                value: TagValue, displayText: String, location: ValueLocation?) {
        self.group = group
        self.name = name
        self.id = id
        self.isUnknown = isUnknown
        self.stored = stored
        self.value = value
        self.displayText = displayText
        self.location = location
    }
}

/// A tag group, such as `IFD0`, `ExifIFD`, `GPS` or `File`.
///
/// Names follow exiftool's family 1 groups. A string-backed struct rather
/// than an enum, so that later versions can add groups without breaking callers.
public struct TagGroup: RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The group name.
    public let rawValue: String

    /// Creates a group from its name.
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Creates a group from its name.
    public init(_ rawValue: String) { self.rawValue = rawValue }
    /// Creates a group from a string literal.
    public init(stringLiteral value: String) { self.rawValue = value }

    /// The group name.
    public var description: String { rawValue }

    /// File type information (`FileType`, `MIMEType`, …).
    public static let file: TagGroup = "File"
    /// The first IFD of the main chain.
    public static let ifd0: TagGroup = "IFD0"
    /// The second IFD of the main chain, usually the thumbnail.
    public static let ifd1: TagGroup = "IFD1"
    /// The Exif IFD.
    public static let exifIFD: TagGroup = "ExifIFD"
    /// The GPS IFD.
    public static let gps: TagGroup = "GPS"
    /// The Interoperability IFD.
    public static let interopIFD: TagGroup = "InteropIFD"

    /// The group of the n-th IFD of the main chain: `IFD0`, `IFD1`, …
    public static func ifd(_ index: Int) -> TagGroup { TagGroup("IFD\(index)") }

    /// The group of the n-th SubIFD: `SubIFD`, `SubIFD1`, `SubIFD2`, …
    public static func subIFD(_ index: Int) -> TagGroup { TagGroup(index == 0 ? "SubIFD" : "SubIFD\(index)") }
}

/// The value of a tag as `exiftool -n` reports it.
public enum TagValue: Sendable, Hashable, CustomStringConvertible {
    /// An integer.
    case integer(Int64)
    /// A decimal number.
    case double(Double)
    /// Text, including lists of numbers separated by spaces.
    case string(String)
    /// Binary data of the given length, not represented as text.
    case binary(length: Int)

    /// The value as text.
    public var description: String {
        switch self {
        case .integer(let v): String(v)
        case .double(let v): String(v)
        case .string(let v): v
        case .binary(let length): "(Binary data \(length) bytes)"
        }
    }
}

/// Where a tag's entry and value are stored.
public struct ValueLocation: Sendable, Hashable {
    /// Absolute file offset of the 12-byte directory entry.
    public let entryOffset: Int
    /// Absolute file offset of the value (inside the entry for values of up to 4 bytes).
    public let valueOffset: Int
    /// Length of the value in bytes.
    public let length: Int

    /// Creates a location.
    public init(entryOffset: Int, valueOffset: Int, length: Int) {
        self.entryOffset = entryOffset
        self.valueOffset = valueOffset
        self.length = length
    }
}
