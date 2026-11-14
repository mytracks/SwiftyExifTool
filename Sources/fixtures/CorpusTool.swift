#if os(macOS)
import ConformanceKit
import Foundation

/// `corpus …` subcommands: the sample corpus of real files (exiftool-conformance
/// spec; design D5 to D7).
struct CorpusTool {
    let packageRoot: URL
    let manifest: CorpusManifest

    init(packageRoot: URL, manifestPath: String?) throws {
        self.packageRoot = packageRoot
        let url = manifestPath.map { URL(fileURLWithPath: $0) }
            ?? packageRoot.appendingPathComponent(CorpusManifest.relativePath)
        manifest = try CorpusManifest.load(from: url)
    }

    var directory: URL { Corpus.directory(packageRoot: packageRoot) }

    func url(_ file: CorpusManifest.File) -> URL { directory.appendingPathComponent(file.fileName) }

    /// Whether a corpus file is present with the manifest's checksum.
    func isValid(_ file: CorpusManifest.File) -> Bool {
        guard FileManager.default.fileExists(atPath: url(file).path) else { return false }
        return (try? Corpus.sha256(of: url(file))) == file.sha256
    }

    /// Downloads every missing or invalid file; keeps a file only when its
    /// SHA-256 matches the manifest.
    func fetch() async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        var failures: [String] = []
        for file in manifest.files {
            if isValid(file) {
                print("ok       \(file.fileName)")
                continue
            }
            print("download \(file.fileName) from \(file.url.absoluteString)")
            do {
                let (temporary, response) = try await URLSession.shared.download(from: file.url)
                defer { try? fm.removeItem(at: temporary) }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    failures.append("\(file.fileName): HTTP \(http.statusCode)")
                    continue
                }
                let checksum = try Corpus.sha256(of: temporary)
                guard checksum == file.sha256 else {
                    failures.append("\(file.fileName): sha256 \(checksum) does not match the manifest (\(file.sha256))")
                    continue
                }
                if fm.fileExists(atPath: url(file).path) { try fm.removeItem(at: url(file)) }
                try fm.moveItem(at: temporary, to: url(file))
            } catch {
                failures.append("\(file.fileName): \(error.localizedDescription)")
            }
        }
        guard failures.isEmpty else {
            throw ToolError("corpus fetch failed:\n  " + failures.joined(separator: "\n  "))
        }
        print("corpus complete in \(directory.path)")
    }

    /// Where corpus snapshots and the baseline are committed.
    static let snapshotRelativeDirectory = "Tests/SwiftyExifToolTests/Snapshots/corpus"

    var snapshotRoot: URL { packageRoot.appendingPathComponent(Self.snapshotRelativeDirectory) }

    /// All manifest files, which must be present with the right checksum.
    func validFiles() throws -> [CorpusManifest.File] {
        var problems: [String] = []
        for file in manifest.files where !isValid(file) {
            let present = FileManager.default.fileExists(atPath: url(file).path)
            problems.append("\(file.fileName): \(present ? "sha256 does not match the manifest" : "missing")")
        }
        guard problems.isEmpty else {
            throw ToolError("corpus not usable (run `swift run fixtures corpus fetch`):\n  " + problems.joined(separator: "\n  "))
        }
        return manifest.files
    }

    /// Records exiftool's output for every corpus file, with personal fields
    /// hashed, into `corpus/exiftool-<version>/<id>.json` (design D6).
    func snapshot() throws {
        let files = try validFiles()
        let version = try Exiftool.version()
        let fm = FileManager.default
        if fm.fileExists(atPath: snapshotRoot.path) {
            for name in try fm.contentsOfDirectory(atPath: snapshotRoot.path) where name.hasPrefix("exiftool-") {
                try fm.removeItem(at: snapshotRoot.appendingPathComponent(name))
            }
        }
        let directory = snapshotRoot.appendingPathComponent("exiftool-\(version)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        let rawArgs = ["-j", "-a", "-G1", "-u", "-n"]
        let displayArgs = ["-j", "-a", "-G1", "-u"]
        for file in files {
            let path = url(file).path
            let raw = hashed(Snapshotter.filtered(try OrderedJSON.parseFirstObject(try Exiftool.run(rawArgs + [path]))))
            let display = hashed(Snapshotter.filtered(try OrderedJSON.parseFirstObject(try Exiftool.run(displayArgs + [path]))))
            let snapshot: [String: Any] = [
                "fixture": file.id,
                "fileName": file.fileName,
                "sha256": file.sha256,
                "exiftoolVersion": version,
                "commands": [rawArgs, displayArgs].map { "exiftool " + $0.joined(separator: " ") + " <file>" },
                "personalFields": "hashed as sha256 (ConformanceKit/PersonalFields.swift)",
                "raw": raw.map { ["key": $0.key, "value": $0.value] },
                "display": display.map { ["key": $0.key, "value": $0.value] },
            ]
            let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try (data + Data("\n".utf8)).write(to: directory.appendingPathComponent("\(file.id).json"))
            print("recorded \(file.id): \(raw.count) entries")
        }
        print("recorded \(files.count) corpus snapshots with exiftool \(version)")
    }

    /// Compares every present corpus file with its snapshot and prints the
    /// report; absent files are listed as skipped (design D7).
    func check() throws {
        for file in manifest.files {
            guard FileManager.default.fileExists(atPath: url(file).path) else {
                print("\(file.id) (\(file.fileName)): skipped, file absent (run `swift run fixtures corpus fetch`)\n")
                continue
            }
            guard isValid(file) else {
                throw ToolError("\(file.fileName): sha256 does not match the manifest")
            }
            let snapshot = try Snapshot.load(file.id, in: snapshotRoot)
            print(CorpusCheck.report(id: file.id, fileName: file.fileName,
                                     comparison: try CorpusCheck.compare(url(file), with: snapshot)))
        }
    }

    /// Re-records `corpus/baseline.json` from all corpus files (design D6).
    func baseline() throws {
        var files: [String: [BaselineEntry]] = [:]
        for file in try validFiles() {
            let snapshot = try Snapshot.load(file.id, in: snapshotRoot)
            files[file.id] = CorpusCheck.baselineEntries(try CorpusCheck.compare(url(file), with: snapshot))
        }
        let baseline = CorpusBaseline(files: files)
        try baseline.json.write(to: snapshotRoot.appendingPathComponent(CorpusBaseline.fileName), atomically: true, encoding: .utf8)
        let counts = files.keys.sorted().map { "\($0) \(files[$0]?.count ?? 0)" }.joined(separator: ", ")
        print("recorded baseline: \(counts)")
    }

    /// Replaces the values of personal fields by their hashes.
    private func hashed(_ entries: [(key: String, value: Any)]) -> [(key: String, value: Any)] {
        entries.map { entry in
            guard PersonalFields.isPersonal(entry.key) else { return entry }
            return (entry.key, PersonalFields.hashed(JSONValue(json: entry.value)).text)
        }
    }
}
#endif
