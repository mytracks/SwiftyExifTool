import Foundation

/// Number and string formatting that reproduces exiftool's observable output
/// (exiftool 13.55, fixture `field-types`).
enum ValueFormatting {
    /// RATIONAL and SRATIONAL: 10 significant digits; `n/0` is `inf`, `0/0` is `undef`.
    static func rational(numerator: Int64, denominator: Int64) -> TagValue {
        if denominator == 0 { return .string(numerator == 0 ? "undef" : "inf") }
        return .double(Double(numerator) / Double(denominator))
    }

    /// Text for a decimal derived from a rational: `%.10g`.
    static func rationalText(_ value: Double) -> String { format(value, digits: 10) }

    /// Text for FLOAT and DOUBLE values (FLOAT widened to DOUBLE first): `%.15g`.
    static func floatingText(_ value: Double) -> String { format(value, digits: 15) }

    static func format(_ value: Double, digits: Int) -> String {
        if value.isNaN { return "nan" }
        if value.isInfinite { return value < 0 ? "-inf" : "inf" }
        return String(format: "%.\(digits)g", value)
    }

    /// Decodes ASCII or UTF-8 bytes without trailing NULs, and without
    /// trailing spaces when `trimSpaces` is set (exiftool trims them only for
    /// some tags; observed per tag, fixture `ascii-trailing-spaces`). Bytes
    /// that are not valid UTF-8 are read as ISO 8859-1 (a deliberate
    /// deviation: exiftool 13.55 prints `?` for them in JSON).
    static func text(_ data: Data, trimSpaces: Bool = true) -> String {
        var bytes = [UInt8](data)
        while let last = bytes.last, last == 0 || (trimSpaces && last == 0x20) { bytes.removeLast() }
        if let string = String(bytes: bytes, encoding: .utf8) { return string }
        return String(bytes.map { Character(Unicode.Scalar($0)) })
    }

    /// Text of a list of values, separated by spaces.
    static func joined(_ items: [String]) -> String { items.joined(separator: " ") }
}

extension TagValue {
    /// The text of this value as exiftool prints it without conversion.
    var exiftoolText: String {
        switch self {
        case .integer(let v): String(v)
        case .double(let v): ValueFormatting.rationalText(v)
        case .string(let v): v
        case .binary(let length): "(Binary data \(length) bytes, use -b option to extract)"
        }
    }

    /// The value as an integer, if it is one.
    var integerValue: Int64? {
        if case .integer(let v) = self { return v }
        return nil
    }
}
