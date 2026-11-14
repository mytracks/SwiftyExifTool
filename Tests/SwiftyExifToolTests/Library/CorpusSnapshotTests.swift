import ConformanceKit
import Foundation
import Testing
@testable import SwiftyExifTool

/// Committed corpus snapshots (exiftool-conformance spec, "Corpus snapshots",
/// "Personal fields are hashed").
@Suite struct CorpusSnapshotTests {
    static var snapshotRoot: URL { FixtureFiles.snapshotDirectory.appendingPathComponent("corpus") }

    static var manifest: CorpusManifest {
        get throws {
            try CorpusManifest.load(from: CorpusManifestTests.packageRoot.appendingPathComponent(CorpusManifest.relativePath))
        }
    }

    @Test func versionNamedSnapshots() throws {
        let directory = try Snapshot.versionDirectory(in: Self.snapshotRoot)
        #expect(directory.lastPathComponent.hasPrefix("exiftool-"))
        for file in try Self.manifest.files {
            let snapshot = try Snapshot.load(file.id, in: Self.snapshotRoot)
            #expect(snapshot.fixture == file.id)
            #expect("exiftool-\(snapshot.exiftoolVersion)" == directory.lastPathComponent)
            #expect(!snapshot.raw.isEmpty && snapshot.raw.count == snapshot.display.count)
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("\(file.id).json"))) as? [String: Any]
            #expect(object?["sha256"] as? String == file.sha256)
            #expect((object?["commands"] as? [String])?.count == 2)
        }
    }

    @Test func personalFieldsAreOnlyHashes() throws {
        for file in try Self.manifest.files {
            let snapshot = try Snapshot.load(file.id, in: Self.snapshotRoot)
            for entry in snapshot.raw + snapshot.display where PersonalFields.isPersonal(entry.key) {
                #expect(PersonalFields.isHashed(JSONValue(json: entry.value)), "\(file.id) \(entry.key) is not hashed")
            }
        }
    }

    /// Needs the corpus: the NEF's artist text never appears in its snapshot.
    @Test(.enabled(if: CorpusSnapshotTests.nefIsPresent))
    func artistOfTheNEFSample() throws {
        let file = try #require(try Self.manifest.files.first { $0.format == "NEF" })
        let corpus = Corpus.directory(packageRoot: CorpusManifestTests.packageRoot)
        let metadata = try MetadataReader.read(contentsOf: corpus.appendingPathComponent(file.fileName))
        let artist = try #require(metadata.tag("IFD0", "Artist")?.displayText)
        #expect(!artist.isEmpty)
        let directory = try Snapshot.versionDirectory(in: Self.snapshotRoot)
        let text = try String(contentsOf: directory.appendingPathComponent("\(file.id).json"), encoding: .utf8)
        #expect(!text.contains(artist))
        #expect(text.contains("\"IFD0:Artist\""))
    }

    static var nefIsPresent: Bool {
        guard let file = try? manifest.files.first(where: { $0.format == "NEF" }) else { return false }
        let corpus = Corpus.directory(packageRoot: CorpusManifestTests.packageRoot)
        return FileManager.default.fileExists(atPath: corpus.appendingPathComponent(file.fileName).path)
    }
}
