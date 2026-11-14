import ConformanceKit
import Foundation
import Testing

/// The sample corpus manifest and location (exiftool-conformance spec).
@Suite struct CorpusManifestTests {
    static var packageRoot: URL {
        guard let root = Corpus.packageRoot(fromSourceFile: #filePath) else { fatalError("no package root above \(#filePath)") }
        return root
    }

    @Test func startingCorpus() throws {
        let manifest = try CorpusManifest.load(from: Self.packageRoot.appendingPathComponent(CorpusManifest.relativePath))
        #expect(Set(manifest.files.map(\.fileName)) == ["compressed_14_bit.NEF", "_DSC0009.ARW", "5G4A9394.CR2", "compress.dng"])
        for file in manifest.files {
            #expect(file.licence == "CC0-1.0")
            #expect(file.url.host == "raw.pixls.us")
            #expect(file.sha256.count == 64)
        }
    }

    @Test func licenceOtherThanCC0() throws {
        let json = #"{"files":[{"id":"x","fileName":"x.nef","url":"https://example.org/x.nef","licence":"CC-BY-4.0","sha256":"\#(String(repeating: "0", count: 64))","camera":"X","format":"NEF","source":"https://example.org/"}]}"#
        #expect {
            try CorpusManifest(data: Data(json.utf8))
        } throws: { error in
            "\(error)".contains("x has licence CC-BY-4.0")
        }
    }

    @Test func directoryResolution() {
        let root = URL(fileURLWithPath: "/tmp/package")
        #expect(Corpus.directory(packageRoot: root, environment: [:]).path == "/tmp/package/Corpus")
        #expect(Corpus.directory(packageRoot: root, environment: ["SWIFTYEXIF_CORPUS": "/data/corpus"]).path == "/data/corpus")
        #expect(Corpus.directory(packageRoot: root, environment: ["SWIFTYEXIF_CORPUS": ""]).path == "/tmp/package/Corpus")
    }

    @Test func checksums() throws {
        #expect(Corpus.sha256(of: "abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("corpus-checksum-\(UUID().uuidString)")
        try Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(try Corpus.sha256(of: url) == Corpus.sha256(of: "abc"))
    }
}
