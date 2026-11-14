import Foundation
import SwiftyExifTool

/// A recorded exiftool snapshot of one fixture (see `swift run fixtures snapshot`).
public struct Snapshot {
    public struct Entry {
        public let group: String
        public let name: String
        public let value: Any

        public var key: String { "\(group):\(name)" }
    }

    public let fixture: String
    public let exiftoolVersion: String
    public let raw: [Entry]
    public let display: [Entry]
    public let verbose: [String]

    /// The newest `exiftool-<version>` directory below `root`.
    public static func versionDirectory(in root: URL) throws -> URL {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        guard let name = names.filter({ $0.hasPrefix("exiftool-") }).sorted().last else {
            throw ConformanceError("no snapshot directory in \(root.path)")
        }
        return root.appendingPathComponent(name)
    }

    /// Loads the snapshot of `fixture` from the newest version directory below `root`.
    public static func load(_ fixture: String, in root: URL) throws -> Snapshot {
        let url = try versionDirectory(in: root).appendingPathComponent("\(fixture).json")
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
            verbose: object["verbose"] as? [String] ?? []
        )
    }

    /// The raw (`-n`) entries without exiftool's own warnings, for comparison.
    public var rawEntries: [ConformanceKit.Entry] { rawTags.map { ConformanceKit.Entry(key: $0.key, value: JSONValue(json: $0.value)) } }
    /// The display entries without exiftool's own warnings, for comparison.
    public var displayEntries: [ConformanceKit.Entry] { displayTags.map { ConformanceKit.Entry(key: $0.key, value: JSONValue(json: $0.value)) } }

    /// Tags excluding exiftool's own warnings.
    public var rawTags: [Entry] { raw.filter { $0.group != "ExifTool" } }
    public var displayTags: [Entry] { display.filter { $0.group != "ExifTool" } }
    public var warnings: [String] { raw.filter { $0.key == "ExifTool:Warning" }.map { "\($0.value)" } }
}

/// Documented, accepted differences between the library and exiftool.
public struct Deviations {
    public struct Item: Decodable, Sendable {
        /// Fixture ID, or `*` for all fixtures.
        public let fixture: String
        /// `Group:Name`, `Group:*` for a whole group, `*:Name` for a name in
        /// any group, or `*` for every tag.
        public let tag: String
        public let reason: String
        /// The spec requirement that sanctions the deviation.
        public let requirement: String

        public func matches(fixture id: String, key: String) -> Bool {
            guard fixture == "*" || fixture == id else { return false }
            if tag == "*" { return true }
            if tag.hasPrefix("*:") { return key.hasSuffix(String(tag.dropFirst())) }
            if tag.hasSuffix(":*") { return key.hasPrefix(String(tag.dropLast())) }
            return tag == key
        }
    }

    public let items: [Item]

    public init(items: [Item]) { self.items = items }

    /// Loads `deviations.json` from the snapshot directory `root`.
    public static func load(from root: URL) throws -> Deviations {
        let url = root.appendingPathComponent("deviations.json")
        return Deviations(items: try JSONDecoder().decode([Item].self, from: Data(contentsOf: url)))
    }

    public func isAccepted(fixture: String, key: String) -> Bool {
        items.contains { $0.matches(fixture: fixture, key: key) }
    }
}
