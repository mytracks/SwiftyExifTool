import ConformanceKit
import Foundation
import Testing

/// Every present corpus file compared with the committed baseline
/// (exiftool-conformance spec, "Corpus baseline"). Without the corpus the
/// test is skipped; fetch it with `swift run fixtures corpus fetch`.
@Suite struct CorpusBaselineTests {
    static var corpusDirectory: URL { Corpus.directory(packageRoot: CorpusManifestTests.packageRoot) }

    /// Manifest IDs whose files are present in the corpus directory.
    static var presentFiles: [String] {
        guard let manifest = try? CorpusSnapshotTests.manifest else { return [] }
        return manifest.files
            .filter { FileManager.default.fileExists(atPath: corpusDirectory.appendingPathComponent($0.fileName).path) }
            .map(\.id)
    }

    @Test("Corpus file matches the baseline",
          .enabled(if: !CorpusBaselineTests.presentFiles.isEmpty,
                   "Corpus absent: fetch it with `swift run fixtures corpus fetch`"),
          arguments: CorpusBaselineTests.presentFiles)
    func corpusFileMatchesBaseline(_ id: String) throws {
        let file = try #require(try CorpusSnapshotTests.manifest.files.first { $0.id == id })
        let url = Self.corpusDirectory.appendingPathComponent(file.fileName)
        let checksum = try Corpus.sha256(of: url)
        try #require(checksum == file.sha256,
                     "\(file.fileName): sha256 \(checksum) does not match the manifest; run `swift run fixtures corpus fetch`")

        let snapshot = try Snapshot.load(id, in: CorpusSnapshotTests.snapshotRoot)
        let baseline = try CorpusBaseline.load(from: CorpusSnapshotTests.snapshotRoot.appendingPathComponent(CorpusBaseline.fileName))
        let expected = try #require(baseline.files[id], "\(id) has no baseline; run `swift run fixtures corpus baseline`")
        let current = CorpusCheck.baselineEntries(try CorpusCheck.compare(url, with: snapshot))
        let changes = CorpusCheck.changes(baseline: expected, current: current)
        #expect(changes.isEmpty, """
            \(id): \(changes.count) keys changed status; review them and run `swift run fixtures corpus baseline`:
            \(changes.prefix(50).joined(separator: "\n"))
            """)
    }

    @Test func changesNameTheKey() {
        let old = [BaselineEntry(key: "IFD0:A", occurrence: 0, status: .missing),
                   BaselineEntry(key: "IFD0:B", occurrence: 1, status: .matching)]
        let new = [BaselineEntry(key: "IFD0:A", occurrence: 0, status: .matching),
                   BaselineEntry(key: "IFD0:C", occurrence: 0, status: .extra)]
        #expect(CorpusCheck.changes(baseline: old, current: new) == [
            "IFD0:A: missing -> matching", "IFD0:B#1: matching -> absent", "IFD0:C: absent -> extra",
        ])
        #expect(CorpusCheck.changes(baseline: old, current: old).isEmpty)
    }

    @Test func baselineJSONRoundTrip() throws {
        let baseline = CorpusBaseline(files: ["x": [BaselineEntry(key: "IFD0:\"Q\"", occurrence: 2, status: .differing)]])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("baseline-\(UUID().uuidString).json")
        try baseline.json.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try CorpusBaseline.load(from: url) == baseline)
    }
}
