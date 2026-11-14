import Foundation

/// Named display formatters. Each output format is confirmed by fixture
/// snapshots (exiftool 13.55); the fixture is named at each formatter.
enum Formatters {
    static func apply(_ formatter: DisplayConversion.Formatter, value: TagValue, stored: StoredValue) -> String {
        switch formatter {
        case .exposureTime:
            return exposureTime(value)
        case .fNumber:
            guard let v = number(value), v != 0 else { return TagFactory.computedText(value) }
            return String(format: "%.1f", v)
        case .exposureBias:
            return exposureBias(value)
        case .dottedVersion:
            if case .bytes(let data) = stored.contents { return data.map(String.init).joined(separator: ".") }
            return value.exiftoolText
        case .suffix(let unit):
            return "\(TagFactory.plainText(value, stored: stored)) \(unit)"
        case .decimalSuffix(let digits, let unit):
            guard let v = number(value) else { return "\(value.exiftoolText) \(unit)" }
            return String(format: "%.\(digits)f", v) + " \(unit)"
        case .lensInfo:
            return lensInfo(stored)
        case .cfaPattern:
            return cfaPattern(value)
        case .gpsCoordinate:
            return gpsCoordinate(value)
        }
    }

    static func number(_ value: TagValue) -> Double? {
        switch value {
        case .integer(let v): Double(v)
        case .double(let v): v
        default: nil
        }
    }

    /// One decimal without a trailing `.0` (observed: `1`, `1.3`, `30`).
    private static func oneDecimal(_ v: Double) -> String {
        var text = String(format: "%.1f", v)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return text
    }

    /// `1/N` below 0.25001 s, otherwise one decimal (fixture `exif-exposuretimes`).
    static func exposureTime(_ value: TagValue) -> String {
        guard let seconds = number(value) else { return value.exiftoolText }
        if seconds <= 0 { return TagFactory.computedText(value) }
        if seconds < 0.25001 { return "1/\(Int64((1 / seconds).rounded()))" }
        return oneDecimal(seconds)
    }

    /// `0`, `+1`, `+1/3`, `-2/3`, `+1/2`, `-5/3`, or two decimals (fixture `exif-bias-brightness`).
    static func exposureBias(_ value: TagValue) -> String {
        guard let v = number(value) else { return value.exiftoolText }
        if v == 0 { return "0" }
        let sign = v < 0 ? "-" : "+"
        let magnitude = abs(v)
        for denominator in [1.0, 2.0, 3.0] {
            let numerator = (magnitude * denominator).rounded()
            if abs(magnitude * denominator - numerator) < 0.001 {
                return denominator == 1 ? "\(sign)\(Int64(numerator))" : "\(sign)\(Int64(numerator))/\(Int64(denominator))"
            }
        }
        var text = String(format: "%.2f", magnitude)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return sign + text
    }

    /// `24-70mm f/2.8`, `18-55mm f/3.5-5.6`, `?mm f/?` (fixture `exif-lensspecification`).
    static func lensInfo(_ stored: StoredValue) -> String {
        guard case .rationals(let r) = stored.contents, r.count == 4 else { return "" }
        let texts = r.map { $0.denominator == 0 ? "?" : ValueFormatting.rationalText(Double($0.numerator) / Double($0.denominator)) }
        func range(_ a: String, _ b: String) -> String { a == b ? a : "\(a)-\(b)" }
        return "\(range(texts[0], texts[1]))mm f/\(range(texts[2], texts[3]))"
    }

    /// `[Red,Green][Green,Blue]` (CIPA DC-008-2026, 4.6.6.7.34; fixture `exif-cfapattern`).
    static func cfaPattern(_ value: TagValue) -> String {
        guard case .string(let text) = value else { return value.exiftoolText }
        let numbers = text.split(separator: " ").compactMap { Int($0) }
        guard numbers.count >= 2 else { return text }
        let (width, height) = (numbers[0], numbers[1])
        let colors = Array(numbers.dropFirst(2))
        guard width > 0, colors.count == width * height else { return text }
        let names = [0: "Red", 1: "Green", 2: "Blue", 3: "Cyan", 4: "Magenta", 5: "Yellow", 6: "White"]
        return (0 ..< height).map { row in
            "[" + colors[row * width ..< (row + 1) * width].map { names[$0] ?? "Unknown (\($0))" }.joined(separator: ",") + "]"
        }.joined()
    }

    /// `48 deg 8' 12.34"` from decimal degrees (fixtures `gps-all-tags`, `gps-coordinates`).
    static func gpsCoordinate(_ value: TagValue) -> String {
        guard let degrees = number(value) else { return value.exiftoolText }
        var d = degrees.rounded(.down)
        let minutesTotal = (degrees - d) * 60
        var m = minutesTotal.rounded(.down)
        var s = ((minutesTotal - m) * 60 * 100).rounded() / 100
        if s >= 60 { s -= 60; m += 1 }
        if m >= 60 { m -= 60; d += 1 }
        return String(format: "%d deg %d' %.2f\"", Int(d), Int(m), s)
    }
}
