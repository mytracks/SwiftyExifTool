import Foundation

/// TIFF field types (TIFF 6.0 section 2), plus UTF-8 from CIPA DC-008 (Exif 3.0 and later).
public enum FieldType: UInt16, Sendable, Hashable, CaseIterable, CustomStringConvertible {
    /// 8-bit unsigned integer.
    case byte = 1
    /// 7-bit ASCII text, NUL-terminated.
    case ascii = 2
    /// 16-bit unsigned integer.
    case short = 3
    /// 32-bit unsigned integer.
    case long = 4
    /// Two LONGs: numerator and denominator.
    case rational = 5
    /// 8-bit signed integer.
    case sbyte = 6
    /// 8-bit byte of any meaning.
    case undefined = 7
    /// 16-bit signed integer.
    case sshort = 8
    /// 32-bit signed integer.
    case slong = 9
    /// Two SLONGs: numerator and denominator.
    case srational = 10
    /// IEEE single-precision floating point.
    case float = 11
    /// IEEE double-precision floating point.
    case double = 12
    /// UTF-8 text, NUL-terminated (Exif 3.0).
    case utf8 = 129

    /// Size of one value in bytes.
    public var size: Int {
        switch self {
        case .byte, .ascii, .sbyte, .undefined, .utf8: 1
        case .short, .sshort: 2
        case .long, .slong, .float: 4
        case .rational, .srational, .double: 8
        }
    }

    /// The type name as in the specifications, e.g. `SHORT`.
    public var description: String {
        switch self {
        case .byte: "BYTE"
        case .ascii: "ASCII"
        case .short: "SHORT"
        case .long: "LONG"
        case .rational: "RATIONAL"
        case .sbyte: "SBYTE"
        case .undefined: "UNDEFINED"
        case .sshort: "SSHORT"
        case .slong: "SLONG"
        case .srational: "SRATIONAL"
        case .float: "FLOAT"
        case .double: "DOUBLE"
        case .utf8: "UTF-8"
        }
    }
}

/// An unsigned fraction as stored in a RATIONAL field.
public struct Rational: Sendable, Hashable, CustomStringConvertible {
    /// The numerator.
    public let numerator: UInt32
    /// The denominator; may be 0 in malformed files.
    public let denominator: UInt32
    /// Creates a fraction.
    public init(_ numerator: UInt32, _ denominator: UInt32) {
        self.numerator = numerator
        self.denominator = denominator
    }
    /// `numerator/denominator`.
    public var description: String { "\(numerator)/\(denominator)" }
}

/// A signed fraction as stored in an SRATIONAL field.
public struct SignedRational: Sendable, Hashable, CustomStringConvertible {
    /// The numerator.
    public let numerator: Int32
    /// The denominator; may be 0 in malformed files.
    public let denominator: Int32
    /// Creates a fraction.
    public init(_ numerator: Int32, _ denominator: Int32) {
        self.numerator = numerator
        self.denominator = denominator
    }
    /// `numerator/denominator`.
    public var description: String { "\(numerator)/\(denominator)" }
}

/// A field exactly as stored in the file.
public struct StoredValue: Sendable, Hashable {
    /// The decoded contents of a field.
    public enum Contents: Sendable, Hashable {
        /// BYTE and UNDEFINED values.
        case bytes(Data)
        /// ASCII and UTF-8 values, as stored (including NUL bytes).
        case text(Data)
        /// SHORT and LONG values.
        case unsigned([UInt32])
        /// SBYTE, SSHORT and SLONG values.
        case signed([Int32])
        /// RATIONAL values.
        case rationals([Rational])
        /// SRATIONAL values.
        case signedRationals([SignedRational])
        /// FLOAT values.
        case floats([Float])
        /// DOUBLE values.
        case doubles([Double])
        /// The value exceeds ``ReadingLimits/maxLoadedValueSize`` and was not read.
        case notLoaded
    }

    /// The stored field type.
    public let fieldType: FieldType
    /// The number of values.
    public let count: UInt32
    /// The decoded values.
    public let contents: Contents

    /// Creates a stored value.
    public init(fieldType: FieldType, count: UInt32, contents: Contents) {
        self.fieldType = fieldType
        self.count = count
        self.contents = contents
    }
}
