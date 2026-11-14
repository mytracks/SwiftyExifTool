import Foundation
import Testing
@testable import SwiftyExifTool

/// Scenarios of the metadata-reading-api spec.
@Suite struct ReadingAPITests {
    @Test func readFixtureFile() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-le"))
        #expect(metadata.fileType == .tiff)
        #expect(metadata.tag(.exifIFD, "ISO")?.value == .integer(200))
    }

    @Test func fileIsLeftUntouched() throws {
        let file = try TemporaryFile(name: "a.tif", data: try FixtureFiles.data("basic-le"))
        defer { file.cleanup() }
        let before = try FileManager.default.attributesOfItem(atPath: file.url.path)[.modificationDate] as? Date
        let bytes = try Data(contentsOf: file.url)
        _ = try MetadataReader.read(contentsOf: file.url)
        #expect(try Data(contentsOf: file.url) == bytes)
        #expect(try FileManager.default.attributesOfItem(atPath: file.url.path)[.modificationDate] as? Date == before)
    }

    @Test(arguments: ["basic-le", "basic-be", "subifds", "unknown-tags", "bad-exif-pointer", "large-undefined"])
    func dataAndFileAgree(_ id: String) throws {
        let fromFile = try MetadataReader.read(contentsOf: FixtureFiles.url(id))
        let fromData = try MetadataReader.read(data: try FixtureFiles.data(id))
        #expect(fromFile == fromData)
    }

    @Test func completeTagRecord() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-le"))
        let entry = try #require(FixtureFiles.fixture("basic-le").layout()?.location("IFD0", 0x0112))
        let tag = try #require(metadata.tag(.ifd0, "Orientation"))
        #expect(tag.group == .ifd0)
        #expect(tag.name == "Orientation")
        #expect(tag.id == 0x0112)
        #expect(!tag.isUnknown)
        #expect(tag.stored == StoredValue(fieldType: .short, count: 1, contents: .unsigned([6])))
        #expect(tag.value == .integer(6))
        #expect(tag.displayText == "Rotate 90 CW")
        #expect(tag.location == ValueLocation(entryOffset: entry.entryOffset, valueOffset: entry.valueOffset, length: 2))
    }

    @Test func lookupWithGroup() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-le"))
        #expect(metadata.tag(.ifd0, "ImageWidth")?.value == .integer(640))
        #expect(metadata.tag(.ifd1, "ImageWidth")?.value == .integer(160))
        #expect(metadata.tag(.gps, "ImageWidth") == nil)
    }

    @Test func lookupByName() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-le"))
        let tags = metadata.tags(named: "ImageWidth")
        #expect(tags.map(\.group) == [.ifd0, .ifd1])
        #expect(metadata.tags(named: "NoSuchTag").isEmpty)
    }

    @Test func readWithWarnings() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("bad-exif-pointer"))
        #expect(metadata.tag(.ifd0, "ImageWidth") != nil)
        #expect(metadata.warnings.count == 1)
        #expect(metadata.warnings[0].group == .exifIFD)
        #expect(metadata.warnings[0].offset == 99999)
    }

    @Test func missingFile() {
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).tif")
        #expect {
            try MetadataReader.read(contentsOf: url)
        } throws: { error in
            guard case ReadError.fileAccess(let failedURL, let reason) = error else { return false }
            return failedURL == url && !reason.isEmpty
        }
    }

    @Test func unsupportedFormat() {
        #expect(throws: ReadError.unsupportedFormat(.png)) {
            try MetadataReader.read(contentsOf: FixtureFiles.url("sig-png"))
        }
    }

    @Test func brokenTIFFIsNotAnError() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("ifd0-beyond-eof"))
        #expect(metadata.tags.allSatisfy { $0.group == .file })
        #expect(!metadata.tags.isEmpty)
        #expect(metadata.warnings.count == 1)
    }

    @Test func repeatedReadIsDeterministic() throws {
        for id in ["basic-le", "self-linked-ifd0", "unknown-field-type"] {
            let url = FixtureFiles.url(id)
            #expect(try MetadataReader.read(contentsOf: url) == MetadataReader.read(contentsOf: url))
        }
    }
}
