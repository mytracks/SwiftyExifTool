import Foundation

/// Everything read from one file.
///
/// Obtain it with ``MetadataReader``. Tags appear in traversal order: the
/// entries of a directory in stored order, with the tags of a sub-directory
/// at the position of its pointer, and chained IFDs after the previous IFD.
public struct Metadata: Sendable, Hashable {
    /// The detected file type.
    public let fileType: FileType
    /// Byte order of the TIFF structure, if the file has one.
    public let byteOrder: ByteOrder?
    /// All tags in traversal order, including the `File` group.
    public let tags: [Tag]
    /// The directories that were read, in traversal order.
    public let directories: [Directory]
    /// Recoverable problems found while reading.
    public let warnings: [ReadWarning]

    /// Creates a result. Normally obtained from ``MetadataReader``.
    public init(fileType: FileType, byteOrder: ByteOrder?, tags: [Tag], directories: [Directory], warnings: [ReadWarning]) {
        self.fileType = fileType
        self.byteOrder = byteOrder
        self.tags = tags
        self.directories = directories
        self.warnings = warnings
    }

    /// The tag with the given group and name, if present.
    public func tag(_ group: TagGroup, _ name: String) -> Tag? {
        tags.first { $0.group == group && $0.name == name }
    }

    /// All tags with the given name, in traversal order.
    public func tags(named name: String) -> [Tag] {
        tags.filter { $0.name == name }
    }
}

/// A file type the library can read.
///
/// A struct rather than an enum, so that later versions can add file types
/// without breaking callers.
public struct FileType: Sendable, Hashable, CustomStringConvertible {
    /// Short name, as in exiftool's `FileType` tag, e.g. `TIFF`.
    public let name: String
    /// Preferred file name extension in upper case, e.g. `TIF`.
    public let fileExtension: String
    /// MIME type, e.g. `image/tiff`.
    public let mimeType: String

    /// Tagged Image File Format; also TIFF-based RAW files until their own types are added.
    public static let tiff = FileType(name: "TIFF", fileExtension: "TIF", mimeType: "image/tiff")

    /// The short name.
    public var description: String { name }
}

/// A directory (IFD) that was read.
public struct Directory: Sendable, Hashable {
    /// The group of the directory's tags, e.g. `IFD0` or `ExifIFD`.
    public let group: TagGroup
    /// Absolute file offset of the directory.
    public let offset: Int
    /// Number of entries the directory declares.
    public let entryCount: Int
    /// The next-IFD offset stored after the entries (0 ends a chain).
    /// `nil` for directories that have no such field.
    public let nextIFDOffset: UInt32?

    /// Creates a directory record.
    public init(group: TagGroup, offset: Int, entryCount: Int, nextIFDOffset: UInt32?) {
        self.group = group
        self.offset = offset
        self.entryCount = entryCount
        self.nextIFDOffset = nextIFDOffset
    }
}

/// A recoverable problem found while reading.
public struct ReadWarning: Sendable, Hashable, CustomStringConvertible {
    /// Human-readable description.
    public let message: String
    /// The group (directory) affected, if any.
    public let group: TagGroup?
    /// The absolute file offset involved, if known.
    public let offset: Int?

    /// Creates a warning.
    public init(_ message: String, group: TagGroup? = nil, offset: Int? = nil) {
        self.message = message
        self.group = group
        self.offset = offset
    }

    /// The message with group and offset.
    public var description: String {
        var text = message
        if let group { text = "[\(group)] " + text }
        if let offset { text += " (offset \(offset))" }
        return text
    }
}

/// Bounds that keep reading predictable for any input.
public struct ReadingLimits: Sendable, Hashable {
    /// Maximum number of directories read per file.
    public var maxDirectories: Int
    /// Maximum nesting depth of sub-directories (IFD0 has depth 0).
    public var maxDepth: Int
    /// Values larger than this many bytes are not loaded; their tags report
    /// field type, count and location only.
    public var maxLoadedValueSize: Int

    /// 256 directories, depth 8, 64 KiB per value.
    public static let `default` = ReadingLimits(maxDirectories: 256, maxDepth: 8, maxLoadedValueSize: 64 * 1024)

    /// Creates custom limits.
    public init(maxDirectories: Int, maxDepth: Int, maxLoadedValueSize: Int) {
        self.maxDirectories = maxDirectories
        self.maxDepth = maxDepth
        self.maxLoadedValueSize = maxLoadedValueSize
    }
}
