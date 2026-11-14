import Foundation

/// Reads metadata from files and in-memory data.
///
/// ```swift
/// let metadata = try MetadataReader.read(contentsOf: url)
/// if let orientation = metadata.tag(.ifd0, "Orientation") {
///     print(orientation.displayText)   // "Rotate 90 CW"
/// }
/// ```
///
/// Reading is synchronous, holds no shared state and may be called from any
/// thread or task, also concurrently. Files are opened read-only, read only
/// where the metadata structure points, and closed before the call returns.
///
/// On iOS and iPadOS, URLs from document pickers are security-scoped: call
/// `startAccessingSecurityScopedResource()` before reading and
/// `stopAccessingSecurityScopedResource()` afterwards. The reader does not
/// do this itself.
public enum MetadataReader {
    /// Reads the metadata of the file at `url`.
    ///
    /// - Throws: ``ReadError/fileAccess(url:reason:)`` if the file cannot be
    ///   opened or read, ``ReadError/unsupportedFormat(_:)`` for recognised
    ///   formats this version cannot read, ``ReadError/unknownFormat`` otherwise.
    ///   Problems inside a readable file are reported as warnings instead.
    public static func read(contentsOf url: URL, limits: ReadingLimits = .default) throws(ReadError) -> Metadata {
        let source: FileByteSource
        do {
            source = try FileByteSource(url: url)
        } catch {
            throw .fileAccess(url: url, reason: Self.reason(error))
        }
        defer { source.close() }
        return try read(source: source, limits: limits) { error in
            .fileAccess(url: url, reason: Self.reason(error))
        }
    }

    /// Reads the metadata contained in `data`, with the same results as
    /// reading a file with these bytes.
    public static func read(data: Data, limits: ReadingLimits = .default) throws(ReadError) -> Metadata {
        try read(source: DataByteSource(data), limits: limits) { _ in .unknownFormat }
    }

    static func read(source: any ByteSource, limits: ReadingLimits,
                     ioError: (ByteSourceError) -> ReadError) throws(ReadError) -> Metadata {
        let prefix: Data
        do {
            prefix = try source.read(offset: 0, count: min(FormatDetector.prefixLength, source.size))
        } catch {
            throw ioError(error)
        }

        switch FormatDetector.detect(prefix) {
        case .unknown:
            throw .unknownFormat
        case .unsupported(let format):
            throw .unsupportedFormat(format)
        case .tiff(let byteOrder):
            var parser = TIFFParser(reader: BinaryReader(source: source, byteOrder: byteOrder), limits: limits)
            parser.parse()
            let fileTags = FileTags.make(fileType: .tiff, byteOrder: byteOrder)
            return Metadata(
                fileType: .tiff,
                byteOrder: byteOrder,
                tags: fileTags + parser.tags,
                directories: parser.directories,
                warnings: parser.warnings
            )
        }
    }

    private static func reason(_ error: ByteSourceError) -> String {
        switch error {
        case .io(let message): message
        case .outOfBounds(let offset, let count): "unexpected end of file reading \(count) bytes at offset \(offset)"
        }
    }
}
