import Foundation
import Testing
import FixtureKit
@testable import SwiftyExifTool

/// Directory traversal (tiff-container spec).
@Suite struct TIFFWalkerTests {
    func read(_ id: String) throws -> Metadata {
        try MetadataReader.read(contentsOf: FixtureFiles.url(id))
    }

    @Test func bigEndianValues() throws {
        #expect(try read("basic-be").tag(.ifd0, "ImageWidth")?.value == .integer(640))
    }

    @Test func sameContentInBothByteOrders() throws {
        func summary(_ m: Metadata) -> [String] {
            m.tags.filter { $0.name != "ExifByteOrder" }.map { "\($0.group):\($0.name)=\($0.value)|\($0.displayText)|\(String(describing: $0.stored))" }
        }
        #expect(summary(try read("basic-le")) == summary(try read("basic-be")))
    }

    @Test func threeChainedIFDs() throws {
        let metadata = try read("ifd-chain")
        #expect(metadata.tags(named: "ImageWidth").map(\.group) == [.ifd(0), .ifd(1), .ifd(2)])
        #expect(metadata.tags(named: "ImageWidth").map(\.value) == [.integer(1), .integer(2), .integer(3)])
    }

    @Test func twoSubIFDs() throws {
        let metadata = try read("subifds")
        #expect(metadata.tag("SubIFD", "ImageWidth")?.value == .integer(2))
        #expect(metadata.tag("SubIFD1", "ImageWidth")?.value == .integer(3))
    }

    @Test func interopInsideExif() throws {
        let metadata = try read("subifds")
        #expect(metadata.tag(.interopIFD, "InteropIndex")?.value == .string("R98"))
    }

    @Test func subdirectoryBeforeIFD1() throws {
        let groups = try read("subifds").tags.filter { $0.group != .file }.map(\.group)
        #expect(groups == [.ifd0, "SubIFD", "SubIFD1", .interopIFD, .ifd1])
    }

    @Test func pointerEntriesAreNotTagsAndDirectoriesAreListed() throws {
        let metadata = try read("exif-gps-interop")
        #expect(!metadata.tags.contains { [0x8769, 0x8825, 0xA005, 0x014A].contains($0.id ?? 0) })
        let layout = try #require(FixtureFiles.fixture("exif-gps-interop").layout())
        #expect(metadata.directories.map(\.group) == [.ifd0, .exifIFD, .interopIFD, .gps])
        #expect(metadata.directories.map(\.offset) == [
            layout.directoryOffsets["IFD0"], layout.directoryOffsets["IFD0/8769"],
            layout.directoryOffsets["IFD0/8769/A005"], layout.directoryOffsets["IFD0/8825"],
        ])
        #expect(metadata.directories.map(\.entryCount) == [3, 2, 1, 1])
        #expect(metadata.directories[0].nextIFDOffset == 0)
    }

    @Test func groupsFromTheSameIDInDifferentTables() throws {
        let metadata = try read("exif-gps-interop")
        #expect(metadata.tag(.gps, "GPSLatitudeRef")?.value == .string("N"))
        #expect(metadata.tag(.interopIFD, "InteropIndex")?.value == .string("R98"))
    }
}
