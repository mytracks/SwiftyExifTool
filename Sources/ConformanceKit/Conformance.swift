import Foundation
import SwiftyExifTool

/// Compares reading results with exiftool snapshots (exiftool-conformance
/// spec, "Comparison with a snapshot"; design D3).
public enum Conformance {
    /// One difference reported by the fixture gate.
    public struct Mismatch: CustomStringConvertible, Sendable {
        public let key: String
        public let kind: String
        public let expected: String
        public let actual: String
        public var description: String { "\(key) \(kind): expected \(expected.debugDescription), got \(actual.debugDescription)" }
    }

    /// The status of one compared key.
    public enum Status: String, Sendable, Codable, CaseIterable {
        case matching, differing, missing, extra
    }

    /// The comparison of one key occurrence.
    public struct KeyComparison: Sendable {
        public let key: String
        /// 0 for the first `Group:Name` member, 1 for its first repetition, ...
        public let occurrence: Int
        public let status: Status
        public let valueDiffers: Bool
        public let displayDiffers: Bool
        public let expectedValue: JSONValue?
        public let actualValue: JSONValue?
        public let expectedDisplay: JSONValue?
        public let actualDisplay: JSONValue?

        public var group: String { key.split(separator: ":", maxSplits: 1).first.map(String.init) ?? key }
    }

    /// Keys in exiftool's order, followed by extra keys in the library's order.
    public struct Comparison: Sendable {
        public let keys: [KeyComparison]
        /// Keys present on both sides, in exiftool's and in the library's order.
        public let expectedOrder: [String]
        public let actualOrder: [String]
    }

    /// Adjusts the library's value before it is compared with exiftool's,
    /// e.g. to hash personal fields: `(key, actual, expected) -> actual`.
    public typealias Prepare = @Sendable (String, JSONValue, JSONValue) -> JSONValue

    /// Renders a JSON value from a snapshot as text.
    public static func text(_ json: Any) -> String {
        if let number = json as? NSNumber, !(json is String) {
            if CFNumberIsFloatType(number) { return "\(number.doubleValue)" }
            return "\(number.int64Value)"
        }
        return "\(json)"
    }

    /// Whether two values match: numbers (or numeric text against a number)
    /// within 1e-9 relative to the larger value, anything else by text.
    public static func valuesMatch(_ expected: JSONValue, _ actual: JSONValue) -> Bool {
        if case .other = expected { return expected.text == actual.text }
        if case .other = actual { return expected.text == actual.text }
        let eitherIsNumber: Bool
        switch (expected, actual) {
        case (.number, _), (_, .number): eitherIsNumber = true
        default: eitherIsNumber = false
        }
        guard eitherIsNumber else { return expected.text == actual.text }
        guard let e = expected.number, let a = actual.number else { return false }
        if e == a { return true }
        return abs(e - a) <= 1e-9 * max(abs(e), abs(a))
    }

    /// Classifies every key occurrence of the library's entries against
    /// exiftool's. `raw` and `display` (and the expected lists) must describe
    /// the same tags in the same order.
    public static func classify(raw: [Entry], display: [Entry], expectedRaw: [Entry], expectedDisplay: [Entry],
                                prepare: Prepare? = nil) -> Comparison {
        func occurrences(_ entries: [Entry]) -> [String] {
            var seen: [String: Int] = [:]
            return entries.map { entry in
                let n = seen[entry.key, default: 0]
                seen[entry.key] = n + 1
                return "\(entry.key)#\(n)"
            }
        }
        let expectedIDs = occurrences(expectedRaw)
        let actualIDs = occurrences(raw)
        var actualIndex: [String: Int] = [:]
        for (index, id) in actualIDs.enumerated() { actualIndex[id] = index }
        let expectedSet = Set(expectedIDs)

        func occurrence(_ id: String) -> Int { Int(id.split(separator: "#").last ?? "0") ?? 0 }

        var keys: [KeyComparison] = []
        for (index, id) in expectedIDs.enumerated() {
            let expected = expectedRaw[index]
            let expectedShown = index < expectedDisplay.count ? expectedDisplay[index].value : nil
            guard let a = actualIndex[id] else {
                keys.append(KeyComparison(key: expected.key, occurrence: occurrence(id), status: .missing,
                                          valueDiffers: false, displayDiffers: false,
                                          expectedValue: expected.value, actualValue: nil,
                                          expectedDisplay: expectedShown, actualDisplay: nil))
                continue
            }
            let actual = raw[a]
            let actualShown = a < display.count ? display[a].value : nil
            var valueDiffers = false
            var displayDiffers = false
            if !actual.isUnknown {
                let actualValue = prepare?(expected.key, actual.value, expected.value) ?? actual.value
                valueDiffers = !valuesMatch(expected.value, actualValue)
                if let expectedShown, let actualShown {
                    let shown = prepare?(expected.key, actualShown, expectedShown) ?? actualShown
                    displayDiffers = !valuesMatch(expectedShown, shown)
                }
            }
            keys.append(KeyComparison(key: expected.key, occurrence: occurrence(id),
                                      status: valueDiffers || displayDiffers ? .differing : .matching,
                                      valueDiffers: valueDiffers, displayDiffers: displayDiffers,
                                      expectedValue: expected.value, actualValue: actual.value,
                                      expectedDisplay: expectedShown, actualDisplay: actualShown))
        }
        for (index, id) in actualIDs.enumerated() where !expectedSet.contains(id) {
            keys.append(KeyComparison(key: raw[index].key, occurrence: occurrence(id), status: .extra,
                                      valueDiffers: false, displayDiffers: false,
                                      expectedValue: nil, actualValue: raw[index].value,
                                      expectedDisplay: nil, actualDisplay: index < display.count ? display[index].value : nil))
        }
        let common = Set(expectedIDs).intersection(actualIDs)
        return Comparison(keys: keys,
                          expectedOrder: expectedIDs.filter(common.contains),
                          actualOrder: actualIDs.filter(common.contains))
    }

    /// Classifies a reading result against a snapshot.
    public static func classify(_ metadata: Metadata, with snapshot: Snapshot, prepare: Prepare? = nil) -> Comparison {
        classify(raw: ExiftoolOutput.entries(metadata, numeric: true),
                 display: ExiftoolOutput.entries(metadata, numeric: false),
                 expectedRaw: snapshot.rawEntries, expectedDisplay: snapshot.displayEntries,
                 prepare: prepare)
    }

    /// The fixture gate: every difference that no deviation covers, including
    /// a different order of the keys present on both sides.
    public static func compare(_ metadata: Metadata, with snapshot: Snapshot, deviations: Deviations,
                               prepare: Prepare? = nil) -> [Mismatch] {
        let comparison = classify(metadata, with: snapshot, prepare: prepare)
        func accepted(_ key: String) -> Bool { deviations.isAccepted(fixture: snapshot.fixture, key: key) }
        var mismatches: [Mismatch] = []

        let expectedOrder = comparison.expectedOrder.filter { !accepted(String($0.split(separator: "#")[0])) }
        let actualOrder = comparison.actualOrder.filter { !accepted(String($0.split(separator: "#")[0])) }
        if expectedOrder != actualOrder {
            let first = Array(zip(expectedOrder, actualOrder)).firstIndex { $0 != $1 } ?? min(expectedOrder.count, actualOrder.count)
            func name(_ list: [String]) -> String { first < list.count ? String(list[first].split(separator: "#")[0]) : "" }
            mismatches.append(Mismatch(key: "*", kind: "order (first difference at \(first))",
                                       expected: name(expectedOrder), actual: name(actualOrder)))
        }

        for key in comparison.keys where !accepted(key.key) {
            switch key.status {
            case .matching:
                break
            case .missing:
                mismatches.append(Mismatch(key: key.key, kind: "missing", expected: key.expectedValue?.text ?? "", actual: ""))
            case .extra:
                mismatches.append(Mismatch(key: key.key, kind: "extra", expected: "", actual: key.actualValue?.text ?? ""))
            case .differing:
                if key.valueDiffers {
                    mismatches.append(Mismatch(key: key.key, kind: "value",
                                               expected: key.expectedValue?.text ?? "", actual: key.actualValue?.text ?? ""))
                }
                if key.displayDiffers {
                    mismatches.append(Mismatch(key: key.key, kind: "display",
                                               expected: key.expectedDisplay?.text ?? "", actual: key.actualDisplay?.text ?? ""))
                }
            }
        }
        return mismatches
    }
}
