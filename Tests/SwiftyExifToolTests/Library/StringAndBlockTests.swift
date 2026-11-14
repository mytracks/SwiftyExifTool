import ConformanceKit
import Foundation
import Testing
@testable import SwiftyExifTool

/// Strings and embedded blocks (exif-tags spec).
@Suite struct StringAndBlockTests {
    let strings = try! MetadataReader.read(contentsOf: FixtureFiles.url("strings"))
    let blocks = try! MetadataReader.read(contentsOf: FixtureFiles.url("embedded-blocks"))

    @Test func paddedMake() {
        #expect(strings.tag(.ifd0, "Make")?.value == .string("Cam"))
        #expect(strings.tag(.ifd0, "Make")?.displayText == "Cam")
    }

    @Test func spacesKeptInImageDescription() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("strings-spaces"))
        #expect(metadata.tag(.ifd0, "ImageDescription")?.value == .string("        "))
        #expect(metadata.tag(.ifd0, "Make")?.value == .string(""))
        #expect(metadata.tag(.ifd0, "Model")?.value == .string("A"))
    }

    @Test func nonUTF8BytesAreLatin1() throws {
        #expect(strings.tag(.ifd0, "Artist")?.value == .string("Müller"))
        // Documented deviation from exiftool's '?' output.
        #expect(try Deviations.load().isAccepted(fixture: "strings", key: "IFD0:Artist"))
    }

    @Test func utf8InASCIIField() {
        #expect(strings.tag(.ifd0, "Software")?.value == .string("Ünïcødé"))
    }

    @Test func makerNoteBlock() throws {
        let tag = try #require(blocks.tags.first { $0.id == 0x927C })
        #expect(tag.group == .exifIFD)
        #expect(tag.value == .binary(length: 64))
        #expect(tag.location?.length == 64)
        #expect(tag.stored?.fieldType == .undefined)
    }

    @Test func xmpBlock() throws {
        let tag = try #require(blocks.tag(.ifd0, "ApplicationNotes"))
        #expect(tag.value == .binary(length: 40))
        #expect(tag.displayText == "(Binary data 40 bytes, use -b option to extract)")
    }

    @Test func iptcAndICCBlocks() {
        #expect(blocks.tag(.ifd0, "IPTC-NAA")?.value == .binary(length: 16))
        #expect(blocks.tag(.ifd0, "ICC_Profile")?.value == .binary(length: 24))
    }

    @Test func blockNamesMatchVerboseObservation() throws {
        let verbose = try Snapshot.load("embedded-blocks").verbose.joined(separator: "\n")
        for definition in EmbeddedBlockTags.all {
            #expect(verbose.contains("\(definition.name) (SubDirectory)"), "\(definition.name)")
            #expect(verbose.contains(String(format: "Tag 0x%04x", definition.id)))
        }
    }
}
