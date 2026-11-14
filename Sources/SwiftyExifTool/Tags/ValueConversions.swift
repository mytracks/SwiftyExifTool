import Foundation

/// Value conversions that need more than the field type.
enum ValueConversions {
    /// Text with an 8-byte character identifier code (CIPA DC-008-2026, 4.6.4, Table 4).
    ///
    /// `ASCII` and undefined codes are read as text. `UNICODE` is UTF-8 in
    /// Exif 3.x; data containing NUL bytes is read as UCS-2 as older writers
    /// produce it, big- or little-endian by which byte of the first character
    /// is zero (observed with exiftool 13.55, fixture `exif-usercomment`).
    /// `JIS` is read as ISO-2022-JP.
    static func characterCodedText(_ data: Data, byteOrder: ByteOrder) -> String {
        let bytes = [UInt8](data)
        guard bytes.count >= 8 else { return ValueFormatting.text(data) }
        let code = bytes[0 ..< 8]
        let payload = Data(bytes[8...])
        switch String(decoding: code.prefix { $0 != 0 }, as: UTF8.self) {
        case "UNICODE":
            if !payload.contains(0), let text = String(data: payload, encoding: .utf8) {
                return trimmed(text)
            }
            return trimmed(ucs2(payload, byteOrder: byteOrder))
        case "JIS":
            return trimmed(String(data: payload, encoding: .iso2022JP) ?? ValueFormatting.text(payload))
        default:
            return ValueFormatting.text(payload)
        }
    }

    private static func ucs2(_ data: Data, byteOrder: ByteOrder) -> String {
        let bytes = [UInt8](data)
        var bigEndian = byteOrder == .bigEndian
        if bytes.count >= 2 {
            if bytes[0] == 0 && bytes[1] != 0 { bigEndian = true }
            if bytes[0] != 0 && bytes[1] == 0 { bigEndian = false }
        }
        var units: [UInt16] = []
        var i = 0
        while i + 1 < bytes.count {
            units.append(bigEndian ? UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1]) : UInt16(bytes[i + 1]) << 8 | UInt16(bytes[i]))
            i += 2
        }
        while units.last == 0 { units.removeLast() }
        return String(decoding: units, as: UTF16.self)
    }

    private static func trimmed(_ text: String) -> String {
        var result = text
        while let last = result.last, last == " " || last == "\0" { result.removeLast() }
        return result
    }

    /// CFA repeat pattern (CIPA DC-008-2026, 4.6.6.7.34): two SHORTs (columns,
    /// rows) followed by one BYTE per cell. The dimensions are read in the
    /// file's byte order, or the other one if only that matches the data
    /// length (observed: exiftool accepts both, fixture `exif-cfapattern`).
    static func cfaPattern(_ data: Data, byteOrder: ByteOrder) -> (width: Int, height: Int, colors: [Int])? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { return nil }
        func dims(_ order: ByteOrder) -> (Int, Int) {
            order == .bigEndian
                ? (Int(bytes[0]) << 8 | Int(bytes[1]), Int(bytes[2]) << 8 | Int(bytes[3]))
                : (Int(bytes[1]) << 8 | Int(bytes[0]), Int(bytes[3]) << 8 | Int(bytes[2]))
        }
        let cells = bytes.count - 4
        let other: ByteOrder = byteOrder == .bigEndian ? .littleEndian : .bigEndian
        for order in [byteOrder, other] {
            let (w, h) = dims(order)
            if w * h == cells, w > 0 { return (w, h, bytes[4...].map(Int.init)) }
        }
        return nil
    }

    /// UNDEFINED bytes as RATIONAL values.
    static func rationals(_ data: Data, byteOrder: ByteOrder) -> [Rational] {
        let bytes = [UInt8](data)
        func u32(_ i: Int) -> UInt32 {
            let b = bytes[i ..< i + 4].map(UInt32.init)
            return byteOrder == .bigEndian ? b[0] << 24 | b[1] << 16 | b[2] << 8 | b[3] : b[3] << 24 | b[2] << 16 | b[1] << 8 | b[0]
        }
        return stride(from: 0, to: bytes.count - 7, by: 8).map { Rational(u32($0), u32($0 + 4)) }
    }

    /// `HH:MM:SS` with fractional seconds when present, e.g. `10:20:30.5`
    /// (observed: fixtures `gps-all-tags`, `gps-timestamp-*`).
    static func timeStamp(seconds total: Double) -> String {
        let rounded = (total * 1_000_000).rounded() / 1_000_000
        let hours = Int(rounded / 3600)
        let minutes = Int((rounded - Double(hours) * 3600) / 60)
        let seconds = rounded - Double(hours) * 3600 - Double(minutes) * 60
        let whole = Int(seconds)
        var text = String(format: "%02d:%02d:%02d", hours, minutes, whole)
        let fraction = seconds - Double(whole)
        if fraction > 1e-9 {
            var digits = String(format: "%.6f", fraction).dropFirst() // ".500000"
            while digits.last == "0" { digits.removeLast() }
            text += digits
        }
        return text
    }
}
