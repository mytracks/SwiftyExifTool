import Foundation
import SwiftyExifTool

/// The texts the tag list shows for one tag.
struct TagRow: Identifiable, Hashable, Sendable {
    /// Position in traversal order; unique within a file.
    let id: Int
    let tag: Tag

    var group: TagGroup { tag.group }
    var name: String { tag.name }
    var isUnknown: Bool { tag.isUnknown }
    /// `Group:Name`, as in exiftool's `-G1` output.
    var qualifiedName: String { "\(tag.group):\(tag.name)" }

    /// Tag ID as four hexadecimal digits, e.g. `0x0112`.
    let idText: String?
    /// Field type name, e.g. `SHORT`.
    let typeText: String?
    let countText: String?
    /// The value as `exiftool -n` prints it.
    let valueText: String
    /// The display text as `exiftool` prints it.
    let displayText: String
    /// Absolute file offset of the value.
    let offsetText: String?

    init(id: Int, tag: Tag) {
        self.id = id
        self.tag = tag
        idText = tag.id.map { String(format: "0x%04X", $0) }
        typeText = tag.stored.map { $0.fieldType.description }
        countText = tag.stored.map { String($0.count) }
        valueText = tag.value.description
        displayText = tag.displayText
        offsetText = tag.location.map { String($0.valueOffset) }
    }

    /// Whether the row matches a search text (case-insensitive) in its name,
    /// hexadecimal ID, value or display text.
    func matches(_ search: String) -> Bool {
        let needle = search.trimmingCharacters(in: .whitespaces)
        if needle.isEmpty { return true }
        return [name, idText ?? "", valueText, displayText].contains { $0.localizedCaseInsensitiveContains(needle) }
    }
}

/// Descriptions of the lossless stored value for the details view.
enum StoredValueText {
    /// Values beyond this count are summarised.
    static let maxItems = 256

    static func describe(_ stored: StoredValue) -> String {
        switch stored.contents {
        case .bytes(let data): return hex(data)
        case .text(let data):
            let text = String(data: data, encoding: .utf8) ?? String(data.map { Character(Unicode.Scalar($0)) })
            return "\"" + text.replacingOccurrences(of: "\0", with: "\\0") + "\""
        case .unsigned(let v): return list(v.map(String.init))
        case .signed(let v): return list(v.map(String.init))
        case .rationals(let v): return list(v.map(\.description))
        case .signedRationals(let v): return list(v.map(\.description))
        case .floats(let v): return list(v.map { String($0) })
        case .doubles(let v): return list(v.map { String($0) })
        case .notLoaded: return "Not loaded (\(Int(stored.count) * stored.fieldType.size) bytes exceed the reading limit)"
        }
    }

    static func hex(_ data: Data) -> String {
        let bytes = data.prefix(maxItems).map { String(format: "%02X", $0) }.joined(separator: " ")
        return data.count > maxItems ? bytes + " … (\(data.count) bytes)" : bytes
    }

    private static func list(_ items: [String]) -> String {
        let shown = items.prefix(maxItems).joined(separator: " ")
        return items.count > maxItems ? shown + " … (\(items.count) values)" : shown
    }
}
