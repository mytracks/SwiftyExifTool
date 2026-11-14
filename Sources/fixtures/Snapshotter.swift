#if os(macOS)
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
        let version = try exiftool(["-ver"]).trimmingCharacters(in: .whitespacesAndNewlines)
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
            let raw = try filtered(OrderedJSON.parseFirstObject(try exiftool(rawArgs + [path])))
            let display = try filtered(OrderedJSON.parseFirstObject(try exiftool(displayArgs + [path])))
            let verbose = verboseDirectoryLines(try exiftool(verboseArgs + [path]))

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

    private func filtered(_ entries: [(key: String, value: Any)]) -> [(key: String, value: Any)] {
        entries.map { entry -> (key: String, value: Any) in
            if let string = entry.value as? String, string.count > Self.maxStringLength {
                return (entry.key, "<snapshot: string of \(string.count) characters omitted>")
            }
            return entry
        }.filter { entry in
            let group = entry.key.split(separator: ":").first.map(String.init) ?? ""
            switch group {
            case "System", "Composite": return false
            case "ExifTool": return entry.key == "ExifTool:Warning" || entry.key == "ExifTool:Error"
            default: return entry.key != "SourceFile"
            }
        }
    }

    /// The `-v2` output from the first directory on; the lines before it are
    /// file-system information that changes between runs.
    private func verboseDirectoryLines(_ text: String) -> [String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("  + [") }) else { return [] }
        return Array(lines[start...]).filter { !$0.isEmpty }
    }

    private func exiftool(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["exiftool"] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus == 127 {
            throw ToolError("exiftool not found on PATH; install it with `brew install exiftool`")
        }
        // exiftool exits with 1 when a file has errors but still prints output.
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw ToolError("exiftool \(arguments.joined(separator: " ")) produced no output (status \(process.terminationStatus))")
        }
        return text
    }
}

struct ToolError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Parses the first object of exiftool's JSON array while keeping key order.
enum OrderedJSON {
    static func parseFirstObject(_ text: String) throws -> [(key: String, value: Any)] {
        let bytes = Array(text.utf8)
        var i = 0
        func skipWhitespace() { while i < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[i]) { i += 1 } }
        func expect(_ c: UInt8) throws {
            skipWhitespace()
            guard i < bytes.count, bytes[i] == c else { throw ToolError("unexpected JSON at \(i)") }
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
            throw ToolError("unterminated JSON value")
        }

        /// Returns the raw text of the JSON string starting at `i`.
        func stringSpan() throws -> String {
            skipWhitespace()
            let start = i
            guard i < bytes.count, bytes[i] == 0x22 else { throw ToolError("expected string at \(i)") }
            i += 1
            while i < bytes.count {
                if bytes[i] == 0x5C { i += 2; continue }
                if bytes[i] == 0x22 { i += 1; return String(decoding: bytes[start ..< i], as: UTF8.self) }
                i += 1
            }
            throw ToolError("unterminated JSON string")
        }

        try expect(0x5B)
        try expect(0x7B)
        var result: [(key: String, value: Any)] = []
        while true {
            skipWhitespace()
            if i < bytes.count, bytes[i] == 0x7D { break }
            let keyText = try stringSpan()
            guard let key = try JSONSerialization.jsonObject(with: Data(keyText.utf8), options: .fragmentsAllowed) as? String else {
                throw ToolError("bad key \(keyText)")
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
#endif
