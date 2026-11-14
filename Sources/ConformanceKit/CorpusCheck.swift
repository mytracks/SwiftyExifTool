import Foundation
import SwiftyExifTool

/// The status of one compared key of a corpus file, as stored in the baseline.
public struct BaselineEntry: Codable, Sendable, Hashable, Comparable {
    public let key: String
    public let occurrence: Int
    public let status: Conformance.Status

    public init(key: String, occurrence: Int, status: Conformance.Status) {
        self.key = key
        self.occurrence = occurrence
        self.status = status
    }

    public static func < (a: BaselineEntry, b: BaselineEntry) -> Bool {
        (a.key, a.occurrence) < (b.key, b.occurrence)
    }
}

/// The committed status of every compared key of every corpus file, without
/// values (exiftool-conformance spec, "Corpus baseline"; design D6).
public struct CorpusBaseline: Sendable, Equatable {
    /// Entries per corpus file ID, sorted by key and occurrence.
    public var files: [String: [BaselineEntry]]

    public init(files: [String: [BaselineEntry]]) { self.files = files }

    public static let fileName = "baseline.json"

    public static func load(from url: URL) throws -> CorpusBaseline {
        struct Raw: Decodable { let files: [String: [BaselineEntry]] }
        return CorpusBaseline(files: try JSONDecoder().decode(Raw.self, from: Data(contentsOf: url)).files)
    }

    /// One entry per line, files and entries sorted, so diffs stay readable.
    public var json: String {
        var lines = ["{", "  \"files\": {"]
        let ids = files.keys.sorted()
        for (fileIndex, id) in ids.enumerated() {
            lines.append("    \(JSONValue.string(id).json): [")
            let entries = (files[id] ?? []).sorted()
            for (index, entry) in entries.enumerated() {
                let comma = index + 1 < entries.count ? "," : ""
                lines.append("      {\"key\": \(JSONValue.string(entry.key).json), \"occurrence\": \(entry.occurrence), \"status\": \"\(entry.status.rawValue)\"}\(comma)")
            }
            lines.append("    ]" + (fileIndex + 1 < ids.count ? "," : ""))
        }
        lines.append("  }")
        lines.append("}")
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Comparing corpus files with their snapshots (design D3, D6, D7).
public enum CorpusCheck {
    /// Reads a corpus file and classifies it against its snapshot, hashing
    /// personal fields. Order is not part of the result.
    public static func compare(_ url: URL, with snapshot: Snapshot) throws -> Conformance.Comparison {
        let metadata = try MetadataReader.read(contentsOf: url)
        return Conformance.classify(metadata, with: snapshot, prepare: PersonalFields.prepare)
    }

    /// The baseline entries of a comparison, sorted.
    public static func baselineEntries(_ comparison: Conformance.Comparison) -> [BaselineEntry] {
        comparison.keys.map { BaselineEntry(key: $0.key, occurrence: $0.occurrence, status: $0.status) }.sorted()
    }

    /// The differences between a baseline and current entries: keys whose
    /// status changed, appeared or disappeared, as readable lines.
    public static func changes(baseline: [BaselineEntry], current: [BaselineEntry]) -> [String] {
        func id(_ e: BaselineEntry) -> String { e.occurrence == 0 ? e.key : "\(e.key)#\(e.occurrence)" }
        let old = Dictionary(baseline.map { (id($0), $0.status) }, uniquingKeysWith: { a, _ in a })
        let new = Dictionary(current.map { (id($0), $0.status) }, uniquingKeysWith: { a, _ in a })
        var lines: [String] = []
        for key in Set(old.keys).union(new.keys).sorted() where old[key] != new[key] {
            lines.append("\(key): \(old[key]?.rawValue ?? "absent") -> \(new[key]?.rawValue ?? "absent")")
        }
        return lines
    }

    /// The report for one corpus file: counts per group, then the keys that
    /// do not match.
    public static func report(id: String, fileName: String, comparison: Conformance.Comparison) -> String {
        var groups: [String] = []
        var counts: [String: [Conformance.Status: Int]] = [:]
        for key in comparison.keys {
            if counts[key.group] == nil { groups.append(key.group) }
            counts[key.group, default: [:]][key.status, default: 0] += 1
        }
        let total = Dictionary(grouping: comparison.keys, by: \.status).mapValues(\.count)
        func pad(_ text: String, _ width: Int) -> String { text.padding(toLength: max(width, text.count), withPad: " ", startingAt: 0) }
        func num(_ n: Int?) -> String { let t = String(n ?? 0); return String(repeating: " ", count: max(0, 8 - t.count)) + t }

        let width = max(16, (groups.map(\.count).max() ?? 0) + 2)
        var lines = ["\(id) (\(fileName)): \(total[.matching] ?? 0) matching, \(total[.differing] ?? 0) differing, "
                     + "\(total[.missing] ?? 0) missing, \(total[.extra] ?? 0) extra"]
        lines.append("  " + pad("group", width) + "   match  differ missing   extra")
        for group in groups {
            let c = counts[group] ?? [:]
            lines.append("  " + pad(group, width) + num(c[.matching]) + num(c[.differing]) + num(c[.missing]) + num(c[.extra]))
        }
        for status in [Conformance.Status.differing, .missing, .extra] {
            let keys = comparison.keys.filter { $0.status == status }
            guard !keys.isEmpty else { continue }
            lines.append("  \(status.rawValue):")
            for key in keys {
                var line = "    \(key.key)"
                if key.occurrence > 0 { line += " #\(key.occurrence)" }
                if status == .differing {
                    if key.valueDiffers { line += "  value \(key.expectedValue?.json ?? "") vs \(key.actualValue?.json ?? "")" }
                    if key.displayDiffers { line += "  display \(key.expectedDisplay?.json ?? "") vs \(key.actualDisplay?.json ?? "")" }
                }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
