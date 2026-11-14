import Foundation
@testable import SwiftyExifTool

/// A recorded exiftool snapshot of one fixture (see `swift run fixtures snapshot`).
struct Snapshot {
    struct Entry {
        let group: String
        let name: String
        let value: Any

        var key: String { "\(group):\(name)" }
    }

    let fixture: String
    let exiftoolVersion: String
    let raw: [Entry]
    let display: [Entry]
    let verbose: [String]

    static var versionDirectory: URL {
        let root = FixtureFiles.snapshotDirectory
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        guard let name = names.filter({ $0.hasPrefix("exiftool-") }).sorted().last else {
            fatalError("no snapshot directory in \(root.path)")
        }
        return root.appendingPathComponent(name)
    }

    static func load(_ fixture: String) throws -> Snapshot {
        let url = versionDirectory.appendingPathComponent("\(fixture).json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        func entries(_ key: String) -> [Entry] {
            (object[key] as! [[String: Any]]).map { item in
                let full = item["key"] as! String
                let parts = full.split(separator: ":", maxSplits: 1).map(String.init)
                return Entry(group: parts[0], name: parts[1], value: item["value"]!)
            }
        }
        return Snapshot(
            fixture: object["fixture"] as! String,
            exiftoolVersion: object["exiftoolVersion"] as! String,
            raw: entries("raw"),
            display: entries("display"),
            verbose: object["verbose"] as! [String]
        )
    }

    /// Tags excluding exiftool's own warnings.
    var rawTags: [Entry] { raw.filter { $0.group != "ExifTool" } }
    var displayTags: [Entry] { display.filter { $0.group != "ExifTool" } }
    var warnings: [String] { raw.filter { $0.key == "ExifTool:Warning" }.map { "\($0.value)" } }
}

/// Documented, accepted differences between the library and exiftool.
struct Deviations {
    struct Item: Decodable {
        /// Fixture ID, or `*` for all fixtures.
        let fixture: String
        /// `Group:Name`, `Group:*` for a whole group, `*:Name` for a name in
        /// any group, or `*` for every tag.
        let tag: String
        let reason: String
        /// The spec requirement that sanctions the deviation.
        let requirement: String

        func matches(fixture id: String, key: String) -> Bool {
            guard fixture == "*" || fixture == id else { return false }
            if tag == "*" { return true }
            if tag.hasPrefix("*:") { return key.hasSuffix(String(tag.dropFirst())) }
            if tag.hasSuffix(":*") { return key.hasPrefix(String(tag.dropLast())) }
            return tag == key
        }
    }

    let items: [Item]

    static func load() throws -> Deviations {
        let url = FixtureFiles.snapshotDirectory.appendingPathComponent("deviations.json")
        return Deviations(items: try JSONDecoder().decode([Item].self, from: Data(contentsOf: url)))
    }

    func isAccepted(fixture: String, key: String) -> Bool {
        items.contains { $0.matches(fixture: fixture, key: key) }
    }
}

/// Compares the library's result for a fixture with its exiftool snapshot.
enum Conformance {
    struct Mismatch: CustomStringConvertible {
        let key: String
        let kind: String
        let expected: String
        let actual: String
        var description: String { "\(key) \(kind): expected \(expected.debugDescription), got \(actual.debugDescription)" }
    }

    /// Renders a JSON value from a snapshot as text.
    static func text(_ json: Any) -> String {
        if let number = json as? NSNumber, !(json is String) {
            if CFNumberIsFloatType(number) { return "\(number.doubleValue)" }
            return "\(number.int64Value)"
        }
        return "\(json)"
    }

    static func numbersMatch(_ expected: Any, _ actual: TagValue) -> Bool? {
        guard let number = expected as? NSNumber, !(expected is String) else { return nil }
        let e = number.doubleValue
        let a: Double
        switch actual {
        case .integer(let v): a = Double(v)
        case .double(let v): a = v
        // exiftool's JSON writes numeric-looking strings as numbers.
        case .string(let s): guard let v = Double(s) else { return false }; a = v
        default: return false
        }
        if e == a { return true }
        return abs(e - a) <= 1e-9 * max(abs(e), abs(a))
    }

    static func compare(_ metadata: Metadata, with snapshot: Snapshot, deviations: Deviations) -> [Mismatch] {
        var mismatches: [Mismatch] = []
        let ours = metadata.tags
        func accepted(_ key: String) -> Bool { deviations.isAccepted(fixture: snapshot.fixture, key: key) }

        // Same tags in the same order.
        let expectedKeys = snapshot.rawTags.map(\.key).filter { !accepted($0) }
        let actualKeys = ours.map { "\($0.group):\($0.name)" }.filter { !accepted($0) }
        if expectedKeys != actualKeys {
            let missing = expectedKeys.filter { !actualKeys.contains($0) }
            let extra = actualKeys.filter { !expectedKeys.contains($0) }
            let firstDifference = Array(zip(expectedKeys, actualKeys)).firstIndex { $0 != $1 } ?? min(expectedKeys.count, actualKeys.count)
            mismatches.append(Mismatch(key: "*", kind: "tag list (first difference at \(firstDifference))",
                                       expected: "missing: " + missing.joined(separator: ", "),
                                       actual: "extra: " + extra.joined(separator: ", ")))
        }

        var remaining = ours
        for (raw, display) in zip(snapshot.rawTags, snapshot.displayTags) where !accepted(raw.key) {
            guard let index = remaining.firstIndex(where: { "\($0.group):\($0.name)" == raw.key }) else { continue }
            let tag = remaining.remove(at: index)
            if tag.isUnknown { continue } // values of unknown tags need not match
            if let match = numbersMatch(raw.value, tag.value) {
                if !match { mismatches.append(Mismatch(key: raw.key, kind: "value", expected: text(raw.value), actual: tag.value.exiftoolText)) }
            } else if text(raw.value) != tag.value.exiftoolText {
                mismatches.append(Mismatch(key: raw.key, kind: "value", expected: text(raw.value), actual: tag.value.exiftoolText))
            }
            let expectedDisplay = text(display.value)
            if expectedDisplay != tag.displayText {
                // Numbers in JSON lose their formatting; compare numerically.
                if let match = numbersMatch(display.value, .string(tag.displayText)), match { continue }
                if let n = display.value as? NSNumber, !(display.value is String), let d = Double(tag.displayText),
                   abs(n.doubleValue - d) <= 1e-9 * max(abs(d), 1e-300) { continue }
                mismatches.append(Mismatch(key: raw.key, kind: "display", expected: expectedDisplay, actual: tag.displayText))
            }
        }
        return mismatches
    }
}
