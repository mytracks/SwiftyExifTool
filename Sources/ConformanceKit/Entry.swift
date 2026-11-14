import Foundation
import SwiftyExifTool

/// A JSON value as exiftool prints it.
public enum JSONValue: Sendable, Hashable, CustomStringConvertible {
    /// A JSON number, kept as its text (e.g. `640`, `0.004`).
    case number(String)
    case string(String)
    /// Any other JSON (arrays, objects, booleans, null), kept as JSON text.
    case other(String)

    /// The value from `JSONSerialization` output.
    public init(json: Any) {
        if let string = json as? String {
            self = .string(string)
        } else if let number = json as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            self = .number(Conformance.text(number))
        } else if let data = try? JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes]) {
            self = .other(String(decoding: data, as: UTF8.self))
        } else {
            self = .other("\(json)")
        }
    }

    /// A text, written as a JSON number when it matches the JSON number
    /// grammar (no leading zeros), otherwise as a string (design D2).
    public init(text: String) {
        self = Self.isJSONNumber(text) ? .number(text) : .string(text)
    }

    /// The text of the value: the number's text, the string, or the JSON text.
    public var text: String {
        switch self {
        case .number(let text), .string(let text), .other(let text): text
        }
    }

    public var description: String { json }

    /// The value as JSON text.
    public var json: String {
        switch self {
        case .number(let text), .other(let text):
            return text
        case .string(let text):
            let data = (try? JSONSerialization.data(withJSONObject: text, options: [.fragmentsAllowed, .withoutEscapingSlashes])) ?? Data()
            return String(decoding: data, as: UTF8.self)
        }
    }

    /// The value as a number, if it is one or its text is numeric.
    var number: Double? {
        switch self {
        case .number(let text), .string(let text): Double(text)
        case .other: nil
        }
    }

    static func isJSONNumber(_ text: String) -> Bool {
        text.range(of: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$"#, options: .regularExpression) != nil
    }
}

/// One member of exiftool's JSON object: a `Group:Name` key and its value.
public struct Entry: Sendable, Hashable {
    public let key: String
    public let value: JSONValue
    /// Whether the library has no definition for the tag; only the key of
    /// such a tag is compared.
    public let isUnknown: Bool

    public init(key: String, value: JSONValue, isUnknown: Bool = false) {
        self.key = key
        self.value = value
        self.isUnknown = isUnknown
    }

    public var group: String { key.split(separator: ":", maxSplits: 1).first.map(String.init) ?? key }
}

/// exiftool-shaped output of reading results (exiftool-conformance spec,
/// "exiftool-shaped output").
public enum ExiftoolOutput {
    /// Whether a key of exiftool's JSON output is compared. `System` and
    /// `Composite`, `SourceFile`, and `ExifTool` members other than warnings
    /// and errors are outside the library's scope.
    public static func isCompared(_ key: String) -> Bool {
        if key == "SourceFile" { return false }
        let group = key.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
        switch group {
        case "System", "Composite": return false
        case "ExifTool": return key == "ExifTool:Warning" || key == "ExifTool:Error"
        default: return true
        }
    }

    /// The entries `exiftool -j -a -G1 -u` prints (or with `-n` when
    /// `numeric`), in the library's traversal order.
    public static func entries(_ metadata: Metadata, numeric: Bool) -> [Entry] {
        metadata.tags.map { tag in
            let key = "\(tag.group.rawValue):\(tag.name)"
            let value: JSONValue
            if numeric {
                switch tag.value {
                case .integer, .double: value = .number(tag.value.description)
                default: value = JSONValue(text: tag.value.description)
                }
            } else {
                value = JSONValue(text: tag.displayText)
            }
            return Entry(key: key, value: value, isUnknown: tag.isUnknown)
        }.filter { isCompared($0.key) }
    }

    /// The JSON text exiftool prints for one file: an array with one object.
    public static func json(_ entries: [Entry]) -> String {
        guard !entries.isEmpty else { return "[{}]\n" }
        let members = entries.map { entry -> String in
            let key = JSONValue.string(entry.key).json
            return "  \(key): \(entry.value.json)"
        }
        return "[{\n" + members.joined(separator: ",\n") + "\n}]\n"
    }
}
