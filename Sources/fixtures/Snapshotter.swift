#if os(macOS)
import ConformanceKit
import FixtureKit
import Foundation

/// Records black-box exiftool output for every TIFF fixture (docs/clean-room.md).
///
/// For each fixture one JSON file is written with:
/// - `raw`: ordered entries of `exiftool -j -a -G1 -u -n`
/// - `display`: ordered entries of `exiftool -j -a -G1 -u`
/// - `verbose`: the directory part of `exiftool -v2`
/// The `System` and `Composite` groups and `ExifTool` tags other than
/// warnings and errors are dropped: they are outside the library's scope.
/// Strings longer than ``maxStringLength`` are replaced by a placeholder.
struct Snapshotter {
    static let relativeDirectory = "Tests/SwiftyExifToolTests/Snapshots"
    let fixtureDirectory: URL
    let snapshotDirectory: URL

    func run() throws {
        let version = try Exiftool.version()
        let fm = FileManager.default
        // Replace snapshots of any earlier exiftool version.
        if fm.fileExists(atPath: snapshotDirectory.path) {
            for name in try fm.contentsOfDirectory(atPath: snapshotDirectory.path) where name.hasPrefix("exiftool-") {
                try fm.removeItem(at: snapshotDirectory.appendingPathComponent(name))
            }
        }
        let directory = snapshotDirectory.appendingPathComponent("exiftool-\(version)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let fixtures = FixtureCatalogue.all.filter(\.isTIFF)
        for fixture in fixtures {
            let path = fixtureDirectory.appendingPathComponent(fixture.fileName).path
            guard fm.fileExists(atPath: path) else {
                throw ToolError("missing \(fixture.fileName); run `swift run fixtures generate` first")
            }
            let rawArgs = ["-j", "-a", "-G1", "-u", "-n"]
            let displayArgs = ["-j", "-a", "-G1", "-u"]
            let verboseArgs = ["-v2"]
            let raw = try Self.filtered(OrderedJSON.parseFirstObject(try Exiftool.run(rawArgs + [path])))
            let display = try Self.filtered(OrderedJSON.parseFirstObject(try Exiftool.run(displayArgs + [path])))
            let verbose = verboseDirectoryLines(try Exiftool.run(verboseArgs + [path]))

            let snapshot: [String: Any] = [
                "fixture": fixture.id,
                "exiftoolVersion": version,
                "commands": [rawArgs, displayArgs, verboseArgs].map { "exiftool " + $0.joined(separator: " ") + " <file>" },
                "raw": raw.map { ["key": $0.key, "value": $0.value] },
                "display": display.map { ["key": $0.key, "value": $0.value] },
                "verbose": verbose,
            ]
            let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try (data + Data("\n".utf8)).write(to: directory.appendingPathComponent("\(fixture.id).json"))
        }
        print("recorded \(fixtures.count) snapshots with exiftool \(version)")
    }

    /// Strings longer than this are replaced by a placeholder to keep snapshots small.
    static let maxStringLength = 1024

    /// Drops keys outside the library's scope (`ExiftoolOutput.isCompared`)
    /// and replaces strings longer than ``maxStringLength`` by a placeholder.
    static func filtered(_ entries: [(key: String, value: Any)]) -> [(key: String, value: Any)] {
        entries.filter { ExiftoolOutput.isCompared($0.key) }.map { entry -> (key: String, value: Any) in
            if let string = entry.value as? String, string.count > Self.maxStringLength {
                return (entry.key, "<snapshot: string of \(string.count) characters omitted>")
            }
            return entry
        }
    }

    /// The `-v2` output from the first directory on; the lines before it are
    /// file-system information that changes between runs.
    private func verboseDirectoryLines(_ text: String) -> [String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("  + [") }) else { return [] }
        return Array(lines[start...]).filter { !$0.isEmpty }
    }
}

struct ToolError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

#endif
