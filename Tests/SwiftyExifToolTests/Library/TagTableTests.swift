import Foundation
import Testing
@testable import SwiftyExifTool

/// Tag tables, unknown values and unknown tags (exif-tags spec).
@Suite struct TagTableTests {
    func read(_ id: String) throws -> Metadata {
        try MetadataReader.read(contentsOf: FixtureFiles.url(id))
    }

    @Test func interopTags() throws {
        let metadata = try read("subifds")
        let tag = try #require(metadata.tag(.interopIFD, "InteropIndex"))
        #expect(tag.value == .string("R98"))
        #expect(tag.displayText == "R98 - DCF basic file (sRGB)")
    }

    @Test func exifTagInIFD0() throws {
        let tag = try #require(try read("exif-in-ifd0").tag(.ifd0, "ExposureTime"))
        #expect(tag.value == .double(0.008))
        #expect(tag.displayText == "1/125")
    }

    @Test func sameIDInGPSAndMainTable() throws {
        let metadata = try read("exif-gps-interop")
        #expect(metadata.tag(.gps, "GPSLatitudeRef")?.id == 0x0001)
        #expect(metadata.tag(.interopIFD, "InteropIndex")?.id == 0x0001)
    }

    @Test func undefinedOrientation() throws {
        let tag = try #require(try read("orientation-unknown").tag(.ifd0, "Orientation"))
        #expect(tag.value == .integer(99))
        #expect(tag.displayText == "Unknown (99)")
    }

    @Test func unknownIFD0Tag() throws {
        let tag = try #require(try read("unknown-tags").tag(.ifd0, "Exif_0xc0de"))
        #expect(tag.isUnknown)
        #expect(tag.value == .integer(7))
        #expect(tag.id == 0xC0DE)
    }

    @Test func unknownGPSAndInteropTags() throws {
        let metadata = try read("unknown-tags")
        let gps = try #require(metadata.tag(.gps, "GPS_0x0077"))
        #expect(gps.isUnknown)
        #expect(gps.value == .integer(9))
        #expect(metadata.tag(.interopIFD, "Exif_0x0077")?.isUnknown == true)
    }

    @Test func knownTagsAreNotFlagged() throws {
        #expect(try read("basic-le").tags.allSatisfy { !$0.isUnknown })
    }

    @Test func displayConversionCases() {
        let short6 = StoredValue(fieldType: .short, count: 1, contents: .unsigned([6]))
        #expect(TagFactory.displayText(value: .integer(6), stored: short6, conversion: .enumeration([6: "six"])) == "six")
        #expect(TagFactory.displayText(value: .integer(7), stored: short6, conversion: .enumeration([6: "six"])) == "Unknown (7)")
        let text = StoredValue(fieldType: .ascii, count: 2, contents: .text(Data("X\0".utf8)))
        #expect(TagFactory.displayText(value: .string("X"), stored: text, conversion: .stringEnumeration(["N": "North"])) == "Unknown (X)")
        #expect(TagFactory.displayText(value: .double(0.5), stored: StoredValue(fieldType: .rational, count: 1, contents: .rationals([Rational(1, 2)])),
                                       conversion: .formatter(.suffix("mm"))) == "0.5 mm")
    }
}
