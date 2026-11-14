import Foundation

/// Why a file could not be read at all.
///
/// Problems inside a recognised file are reported as ``ReadWarning``s
/// instead. Later versions may add cases; keep a `default` branch when
/// switching over this type.
public enum ReadError: Error, Sendable, Hashable, CustomStringConvertible {
    /// The file could not be opened or read.
    case fileAccess(url: URL, reason: String)
    /// The format was recognised but is not supported.
    case unsupportedFormat(DetectedFormat)
    /// The content matches no known format.
    case unknownFormat

    /// A human-readable description.
    public var description: String {
        switch self {
        case .fileAccess(let url, let reason): "Cannot read \(url.path): \(reason)"
        case .unsupportedFormat(let format): "Unsupported format: \(format)"
        case .unknownFormat: "Unknown file format"
        }
    }
}

/// A recognised format that this version cannot read.
public enum DetectedFormat: Sendable, Hashable, CustomStringConvertible {
    /// BigTIFF (TIFF version 43).
    case bigTIFF
    /// JPEG.
    case jpeg
    /// PNG.
    case png
    /// An ISO base media file (e.g. HEIF, CR3, MP4) with its major brand.
    case isoBMFF(majorBrand: String)

    /// The format name.
    public var description: String {
        switch self {
        case .bigTIFF: "BigTIFF"
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .isoBMFF(let brand): "ISO BMFF (brand \(brand))"
        }
    }
}
