import Foundation
import Testing
import FixtureKit
@testable import SwiftyExifTool

/// Malformed structure and resource limits (tiff-container spec).
@Suite struct TIFFRobustnessTests {
    func read(_ id: String, limits: ReadingLimits = .default) throws -> Metadata {
        try MetadataReader.read(contentsOf: FixtureFiles.url(id), limits: limits)
    }

    func nonFileTags(_ m: Metadata) -> [SwiftyExifTool.Tag] { m.tags.filter { $0.group != .file } }

    @Test func unknownFieldTypeIsSkipped() throws {
        let metadata = try read("unknown-field-type")
        #expect(nonFileTags(metadata).map(\.name) == ["ImageWidth", "Make"])
        #expect(metadata.warnings.count == 1)
        #expect(metadata.warnings[0].message.contains("99"))
        #expect(metadata.warnings[0].message.contains("0x0101"))
        #expect(metadata.warnings[0].group == .ifd0)
    }

    @Test func outOfBoundsSubdirectory() throws {
        let metadata = try read("bad-exif-pointer")
        #expect(metadata.tag(.ifd0, "ImageWidth")?.value == .integer(10))
        #expect(metadata.warnings.count == 1)
        #expect(metadata.warnings[0].group == .exifIFD)
        #expect(metadata.warnings[0].message.contains("Bad ExifIFD directory"))
        #expect(metadata.warnings[0].offset == 99999)
    }

    @Test func truncatedIFD0() throws {
        let metadata = try read("truncated-ifd0")
        #expect(nonFileTags(metadata).isEmpty)
        #expect(metadata.tag(.file, "FileType") != nil)
        #expect(metadata.warnings.map(\.message) == ["Bad IFD0 directory"])
        #expect(metadata.directories.isEmpty)
    }

    @Test func valueBeyondEndOfFile() throws {
        let metadata = try read("value-beyond-eof")
        #expect(nonFileTags(metadata).map(\.name) == ["ImageWidth", "Model"])
        #expect(metadata.warnings.count == 1)
        #expect(metadata.warnings[0].message.contains("0x010f"))
    }

    @Test func ifd0BeyondEndOfFile() throws {
        let metadata = try read("ifd0-beyond-eof")
        #expect(nonFileTags(metadata).isEmpty)
        #expect(metadata.warnings.map(\.message) == ["Bad IFD0 directory"])
    }

    @Test func selfLinkedIFD0() throws {
        let metadata = try read("self-linked-ifd0")
        #expect(nonFileTags(metadata).map(\.group) == [.ifd0, .ifd0])
        #expect(metadata.warnings.count == 1)
        #expect(metadata.warnings[0].message.contains("previously read"))
        #expect(metadata.warnings[0].group == .ifd1)
    }

    @Test func subdirectoryPointingToItsParent() throws {
        // An ExifIFD pointer that points back to IFD0.
        let data = TIFFBuilder(.little, chain: [.init([
            .short(0x0100, 1),
            .init(tag: 0x8769, type: 4, count: 1, payload: .valueField(8)),
        ])]).build().data
        let metadata = try MetadataReader.read(data: data)
        #expect(nonFileTags(metadata).count == 1)
        #expect(metadata.warnings.count == 1)
        #expect(metadata.warnings[0].group == .exifIFD)
    }

    @Test func tooManyDirectories() throws {
        let metadata = try read("too-many-ifds")
        #expect(metadata.directories.count == ReadingLimits.default.maxDirectories)
        #expect(nonFileTags(metadata).count == ReadingLimits.default.maxDirectories)
        #expect(metadata.warnings.count == 1)
        #expect(metadata.warnings[0].message.contains("limit"))
    }

    @Test func customDirectoryLimit() throws {
        let limits = ReadingLimits(maxDirectories: 3, maxDepth: 8, maxLoadedValueSize: 1024)
        let metadata = try read("too-many-ifds", limits: limits)
        #expect(metadata.directories.count == 3)
    }

    @Test func depthLimit() throws {
        let limits = ReadingLimits(maxDirectories: 256, maxDepth: 1, maxLoadedValueSize: 1024)
        let metadata = try read("subifds", limits: limits)
        #expect(metadata.tag(.interopIFD, "InteropIndex") == nil)
        #expect(metadata.tag("SubIFD", "ImageWidth") != nil)
        #expect(metadata.warnings.contains { $0.message.contains("depth") })
    }

    @Test func largeBinaryValueIsNotLoaded() throws {
        let metadata = try read("large-undefined")
        let tag = try #require(metadata.tags.first { $0.id == 0xF001 })
        #expect(tag.stored?.contents == .notLoaded)
        #expect(tag.stored?.count == 1 << 20)
        #expect(tag.location?.length == 1 << 20)
        #expect(tag.value == .binary(length: 1 << 20))
        #expect(metadata.warnings.isEmpty)
    }

    @Test func hugeDeclaredCountDoesNotAllocate() throws {
        // A count of 0xFFFFFFFF DOUBLEs: the size check rejects it before reading.
        let data = TIFFBuilder(.little, chain: [.init([
            .init(tag: 0x0100, type: 12, count: 0xFFFF_FFFF, payload: .valueField(8)),
        ])]).build().data
        let metadata = try MetadataReader.read(data: data)
        #expect(nonFileTags(metadata).isEmpty)
        #expect(metadata.warnings.count == 1)
    }

    @Test func truncatedHeader() throws {
        let metadata = try MetadataReader.read(data: Data([0x49, 0x49, 0x2A, 0x00, 0x08]))
        #expect(nonFileTags(metadata).isEmpty)
        #expect(metadata.warnings.count == 1)
    }
}
