import Foundation

/// Identifies a file's format from its leading bytes.
///
/// Signatures:
/// - TIFF: `II*\0` / `MM\0*` (TIFF 6.0, section 2 "Image File Header")
/// - BigTIFF: TIFF byte order mark with version 43 (BigTIFF design)
/// - JPEG: SOI marker followed by a marker prefix, `FF D8 FF` (ITU-T T.81, B.1.1.3)
/// - PNG: `89 50 4E 47 0D 0A 1A 0A` (PNG specification, 5.2)
/// - ISO BMFF: `ftyp` box type at bytes 4–7, major brand at 8–11 (ISO/IEC 14496-12, 4.3)
enum FormatDetector {
    enum Result: Equatable {
        case tiff(ByteOrder)
        case unsupported(DetectedFormat)
        case unknown
    }

    /// Number of leading bytes ``detect(_:)`` looks at.
    static let prefixLength = 12

    static func detect(_ prefix: Data) -> Result {
        let b = [UInt8](prefix.prefix(prefixLength))

        if b.count >= 4 {
            switch (b[0], b[1], b[2], b[3]) {
            case (0x49, 0x49, 0x2A, 0x00): return .tiff(.littleEndian)
            case (0x4D, 0x4D, 0x00, 0x2A): return .tiff(.bigEndian)
            case (0x49, 0x49, 0x2B, 0x00), (0x4D, 0x4D, 0x00, 0x2B): return .unsupported(.bigTIFF)
            default: break
            }
        }
        if b.count >= 3, b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF {
            return .unsupported(.jpeg)
        }
        if b.count >= 8, b[0 ..< 8] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] {
            return .unsupported(.png)
        }
        if b.count >= 12, b[4 ..< 8] == Array("ftyp".utf8)[...] {
            let brand = String(decoding: b[8 ..< 12], as: UTF8.self)
            return .unsupported(.isoBMFF(majorBrand: brand))
        }
        return .unknown
    }
}
