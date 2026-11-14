import Foundation
import Testing
import FixtureKit
@testable import SwiftyExifTool

/// Directory entries and field types (tiff-container spec).
@Suite struct TIFFEntryTests {
    let fieldTypes = try! MetadataReader.read(contentsOf: FixtureFiles.url("field-types"))

    func stored(_ index: Int) -> StoredValue? {
        let id = 0xF001 + UInt16(index)
        return fieldTypes.tags.first { $0.id == id }?.stored
    }

    @Test func everyFieldTypeIsDecoded() throws {
        let expected: [(FieldType, StoredValue.Contents)] = [
            (.byte, .bytes(Data([7]))), (.byte, .bytes(Data([1, 2, 3]))),
            (.ascii, .text(Data("A\0".utf8))), (.ascii, .text(Data("ABCDEFG\0".utf8))),
            (.short, .unsigned([65535])), (.short, .unsigned([1, 2, 3])),
            (.long, .unsigned([4_000_000_000])), (.long, .unsigned([1, 2, 3])),
            (.rational, .rationals([Rational(1, 3)])), (.rational, .rationals([Rational(1, 2), Rational(3, 4), Rational(5, 6)])),
            (.sbyte, .signed([-5])), (.sbyte, .signed([-1, 0, 1])),
            (.undefined, .bytes(Data([0xAB]))), (.undefined, .bytes(Data([1, 2, 3]))),
            (.sshort, .signed([-300])), (.sshort, .signed([-1, 0, 1])),
            (.slong, .signed([-70000])), (.slong, .signed([-1, 0, 1])),
            (.srational, .signedRationals([SignedRational(-1, 3)])),
            (.srational, .signedRationals([SignedRational(-1, 2), SignedRational(3, -4), SignedRational(5, 6)])),
            (.float, .floats([1.5])), (.float, .floats([-0.25, 0, 2])),
            (.double, .doubles([3.25])), (.double, .doubles([-1e10, 0, 0.125])),
        ]
        for (index, (type, contents)) in expected.enumerated() {
            let value = try #require(stored(index), "entry \(index)")
            #expect(value.fieldType == type, "entry \(index)")
            #expect(value.contents == contents, "entry \(index)")
        }
    }

    @Test func utf8String() throws {
        let value = try #require(stored(24))
        #expect(value.fieldType == .utf8)
        let tag = try #require(fieldTypes.tags.first { $0.id == 0xF019 })
        #expect(tag.value == .string("Zürich"))
    }

    @Test func inlineAndOffsetValues() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-le"))
        let layout = try #require(FixtureFiles.fixture("basic-le").layout())

        let width = try #require(metadata.tag(.ifd0, "ImageWidth"))
        #expect(width.value == .integer(640))
        let widthEntry = try #require(layout.location("IFD0", 0x0100))
        #expect(width.location == ValueLocation(entryOffset: widthEntry.entryOffset, valueOffset: widthEntry.entryOffset + 8, length: 2))

        let make = try #require(metadata.tag(.ifd0, "Make"))
        #expect(make.value == .string("TestCam"))
        let makeEntry = try #require(layout.location("IFD0", 0x010F))
        #expect(make.location == ValueLocation(entryOffset: makeEntry.entryOffset, valueOffset: makeEntry.valueOffset, length: 8))
        #expect(makeEntry.valueOffset > makeEntry.entryOffset + 8)
    }

    @Test func offsetOfOutOfLineValue() throws {
        // Make as an 8-byte string placed at file offset 110.
        var builder = TIFFBuilder(.little, chain: [.init([
            .short(0x0100, 1),
            .init(tag: 0x010F, type: 2, count: 8, payload: .valueField(110)),
        ])])
        builder.patches = [(offset: 110, bytes: Array("TestCam\0".utf8))]
        var data = builder.build().data
        data.append(Data(count: 120 - data.count))
        data.replaceSubrange(110 ..< 118, with: Array("TestCam\0".utf8))

        let make = try #require(try MetadataReader.read(data: data).tag(.ifd0, "Make"))
        #expect(make.location?.valueOffset == 110)
        #expect(make.location?.length == 8)
        #expect(make.value == .string("TestCam"))
    }

    @Test func fieldTypeAndCountAreReported() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-le"))
        let xResolution = try #require(metadata.tag(.ifd0, "XResolution"))
        #expect(xResolution.stored == StoredValue(fieldType: .rational, count: 1, contents: .rationals([Rational(300, 1)])))
        #expect(xResolution.id == 0x011A)
    }
}
