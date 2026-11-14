import Foundation

/// The ID space a directory's tags are looked up in.
enum TagTable: Sendable, Hashable {
    /// IFD0, IFD1, …, SubIFDs, ExifIFD and InteropIFD share one table
    /// (observed with exiftool 13.55, fixtures `exif-in-ifd0`, `subifds`).
    case main
    /// The GPS directory.
    case gps
}

/// Where a definition comes from (docs/clean-room.md, "Provenance").
enum Provenance: Sendable, Hashable {
    enum Document: String, Sendable, Hashable {
        case tiff6 = "TIFF Revision 6.0 (1992)"
        case tiffTechNotes = "Adobe PageMaker 6.0 TIFF Technical Notes (1995)"
        case exif = "CIPA DC-008-2026 (Exif 3.1)"
        case xmpPart3 = "XMP Specification Part 3 (Adobe)"
        case iccEmbedding = "ICC Technical Note: Embedding ICC profiles"
    }

    /// A published specification, with the section, table or page.
    case specification(Document, section: String)
    /// Black-box observation of exiftool on a committed fixture; the
    /// snapshot records the command and exiftool version.
    case observation(fixture: String)

    static func tiff6(_ section: String) -> Provenance { .specification(.tiff6, section: section) }
    static func exif(_ section: String) -> Provenance { .specification(.exif, section: section) }
    static func xmpPart3(_ section: String) -> Provenance { .specification(.xmpPart3, section: section) }
}

/// How a tag's stored value becomes its display text.
///
/// A closed set of cases so tests can enumerate them. The texts themselves
/// are confirmed by the exiftool snapshots of the fixtures.
enum DisplayConversion: Sendable {
    /// The display text is the value's text.
    case none
    /// Integer values mapped to texts; others become `Unknown (<value>)`.
    case enumeration([Int64: String])
    /// String values mapped to texts; others become `Unknown (<value>)`.
    case stringEnumeration([String: String])
    /// Each value of a list mapped like ``enumeration(_:)``, joined by `separator`.
    case enumerationList([Int64: String], separator: String)
    /// Bit index to name; set bits joined by `, `, `(none)` for 0, `[n]` for
    /// undefined bits (observed: fixture `tiff-t4options`).
    case bitField([Int: String])
    /// A named formatter for values that need computation.
    case formatter(Formatter)

    enum Formatter: Sendable {
        /// Exposure time as a fraction, e.g. `1/250`, or one decimal from 0.25 s on.
        case exposureTime
        /// F-number with one decimal, e.g. `2.8`; `0` stays `0`.
        case fNumber
        /// Exposure bias as a signed fraction of 1/2 or 1/3 steps, e.g. `+1/3`.
        case exposureBias
        /// Bytes joined with dots, e.g. GPSVersionID `2.3.0.0`.
        case dottedVersion
        /// Appends a unit after the value text, e.g. `2.5 m`.
        case suffix(String)
        /// The value with a fixed number of decimals and a unit, e.g. `50.0 mm`.
        case decimalSuffix(digits: Int, unit: String)
        /// Focal length and aperture range, e.g. `24-70mm f/2.8`.
        case lensInfo
        /// Colour filter array rows, e.g. `[Red,Green][Green,Blue]`.
        case cfaPattern
        /// Degrees, minutes and seconds, e.g. `48 deg 8' 12.34"`.
        case gpsCoordinate
    }
}

/// How a tag's stored value becomes its value (as `exiftool -n` prints it).
enum ValueConversion: Sendable {
    /// Derived from the field type (see ``TagFactory``).
    case automatic
    /// UNDEFINED bytes read as text, e.g. ExifVersion `0232`.
    case undefinedText
    /// Binary data reported only by length.
    case binary
    /// Reported as binary data whose length is that of the value's text
    /// (observed for GrayResponseCurve and TransferFunction, fixture `tiff-all-tags`).
    case binaryOfText
    /// APEX shutter speed to seconds: 2^-v.
    case apexShutterSpeed
    /// APEX aperture to f-number: 2^(v/2).
    case apexAperture
    /// Text with an 8-byte character code prefix (Exif 4.6.4).
    case characterCodedText
    /// CFA repeat pattern: width, height and colours (Exif 4.6.6.7.34).
    case cfaPattern
    /// UNDEFINED bytes read as RATIONAL values in the file's byte order.
    case undefinedRationals
    /// Degrees, minutes and seconds to decimal degrees.
    case gpsCoordinate
    /// Hours, minutes and seconds to `HH:MM:SS[.ss]`.
    case gpsTimeStamp
}

/// A tag definition from a published specification.
struct TagDefinition: Sendable {
    let id: UInt16
    let name: String
    let table: TagTable
    let value: ValueConversion
    let display: DisplayConversion
    let source: Provenance
    /// Names that replace ``name`` in specific groups (exact group names).
    let groupNames: [(group: String, name: String)]
    /// Whether trailing spaces are removed from text values (observed per tag,
    /// fixture `ascii-trailing-spaces`).
    let trimsTrailingSpaces: Bool

    init(_ id: UInt16, _ name: String, table: TagTable = .main, value: ValueConversion = .automatic,
         display: DisplayConversion = .none, groupNames: [(group: String, name: String)] = [],
         trimsTrailingSpaces: Bool = false, source: Provenance) {
        self.id = id
        self.name = name
        self.groupNames = groupNames
        self.trimsTrailingSpaces = trimsTrailingSpaces
        self.table = table
        self.value = value
        self.display = display
        self.source = source
    }

    /// The name used in `group`.
    func name(in group: TagGroup) -> String {
        groupNames.first { group.rawValue == $0.group }?.name ?? name
    }

    /// Every name this definition can produce.
    var allNames: [String] { [name] + groupNames.map(\.name) }
}
