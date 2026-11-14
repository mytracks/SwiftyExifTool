import Foundation

/// An error from the conformance tooling.
public struct ConformanceError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

/// Parses the first object of exiftool's JSON array while keeping key order
/// and repeated keys (exiftool's `-a` repeats keys within a group).
public enum OrderedJSON {
    public static func parseFirstObject(_ text: String) throws -> [(key: String, value: Any)] {
        let bytes = Array(text.utf8)
        var i = 0
        func skipWhitespace() { while i < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[i]) { i += 1 } }
        func expect(_ c: UInt8) throws {
            skipWhitespace()
            guard i < bytes.count, bytes[i] == c else { throw ConformanceError("unexpected JSON at \(i)") }
            i += 1
        }
        /// Returns the raw text of the JSON value starting at `i`.
        func valueSpan() throws -> String {
            skipWhitespace()
            let start = i
            var depth = 0
            var inString = false
            while i < bytes.count {
                let c = bytes[i]
                if inString {
                    if c == 0x5C { i += 2; continue }
                    if c == 0x22 { inString = false }
                } else {
                    switch c {
                    case 0x22: inString = true
                    case 0x5B, 0x7B: depth += 1
                    case 0x5D, 0x7D:
                        if depth == 0 { return String(decoding: bytes[start ..< i], as: UTF8.self) }
                        depth -= 1
                    case 0x2C where depth == 0:
                        return String(decoding: bytes[start ..< i], as: UTF8.self)
                    default: break
                    }
                }
                i += 1
            }
            throw ConformanceError("unterminated JSON value")
        }

        /// Returns the raw text of the JSON string starting at `i`.
        func stringSpan() throws -> String {
            skipWhitespace()
            let start = i
            guard i < bytes.count, bytes[i] == 0x22 else { throw ConformanceError("expected string at \(i)") }
            i += 1
            while i < bytes.count {
                if bytes[i] == 0x5C { i += 2; continue }
                if bytes[i] == 0x22 { i += 1; return String(decoding: bytes[start ..< i], as: UTF8.self) }
                i += 1
            }
            throw ConformanceError("unterminated JSON string")
        }

        try expect(0x5B)
        try expect(0x7B)
        var result: [(key: String, value: Any)] = []
        while true {
            skipWhitespace()
            if i < bytes.count, bytes[i] == 0x7D { break }
            let keyText = try stringSpan()
            guard let key = try JSONSerialization.jsonObject(with: Data(keyText.utf8), options: .fragmentsAllowed) as? String else {
                throw ConformanceError("bad key \(keyText)")
            }
            try expect(0x3A)
            let valueText = try valueSpan()
            let value = try JSONSerialization.jsonObject(with: Data(valueText.utf8), options: .fragmentsAllowed)
            result.append((key, value))
            skipWhitespace()
            if i < bytes.count, bytes[i] == 0x2C { i += 1 }
        }
        return result
    }
}
