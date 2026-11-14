import Foundation
import Testing
@testable import SwiftyExifTool

/// Scenarios of the file-type-detection spec.
@Suite struct FileTypeDetectionTests {
    func read(_ id: String, as name: String) throws(ReadError) -> Metadata {
        let file = try! TemporaryFile(name: name, data: try! FixtureFiles.data(id))
        defer { file.cleanup() }
        return try MetadataReader.read(contentsOf: file.url)
    }

    func expectError(_ id: String, as name: String = "file.bin", _ expected: ReadError) {
        #expect(throws: expected) { try read(id, as: name) }
    }

    @Test func tiffWithMisleadingExtension() throws {
        let metadata = try read("basic-le", as: "photo.jpg")
        #expect(metadata.fileType == .tiff)
        #expect(metadata.tag(.ifd0, "Make")?.value == .string("TestCam"))
    }

    @Test func jpegWithTIFFExtension() {
        expectError("sig-jpeg", as: "image.tif", .unsupportedFormat(.jpeg))
    }

    @Test func littleEndianTIFF() throws {
        #expect(FormatDetector.detect(Data([0x49, 0x49, 0x2A, 0x00])) == .tiff(.littleEndian))
        #expect(try read("basic-le", as: "a.tif").byteOrder == .littleEndian)
    }

    @Test func bigEndianTIFF() throws {
        #expect(FormatDetector.detect(Data([0x4D, 0x4D, 0x00, 0x2A])) == .tiff(.bigEndian))
        #expect(try read("basic-be", as: "a.tif").byteOrder == .bigEndian)
    }

    @Test func bigTIFF() {
        expectError("sig-bigtiff", .unsupportedFormat(.bigTIFF))
        #expect(FormatDetector.detect(Data([0x4D, 0x4D, 0x00, 0x2B])) == .unsupported(.bigTIFF))
    }

    @Test func png() {
        expectError("sig-png", .unsupportedFormat(.png))
    }

    @Test func isoBMFFWithBrand() {
        expectError("sig-isobmff", .unsupportedFormat(.isoBMFF(majorBrand: "abcd")))
        #expect(ReadError.unsupportedFormat(.isoBMFF(majorBrand: "abcd")).description.contains("abcd"))
    }

    @Test func textFile() {
        expectError("sig-text", .unknownFormat)
    }

    @Test func emptyFile() {
        expectError("sig-empty", .unknownFormat)
        #expect(throws: ReadError.unknownFormat) { try MetadataReader.read(data: Data()) }
    }

    @Test func shortFiles() {
        for prefix in [[0x49], [0x49, 0x49, 0x2A], [0xFF, 0xD8]] as [[UInt8]] {
            #expect(throws: ReadError.unknownFormat) { try MetadataReader.read(data: Data(prefix)) }
        }
    }

    @Test func bigEndianFileTags() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-be"))
        #expect(metadata.tag(.file, "FileType")?.value == .string("TIFF"))
        #expect(metadata.tag(.file, "MIMEType")?.value == .string("image/tiff"))
        #expect(metadata.tag(.file, "FileTypeExtension")?.value == .string("TIF"))
        #expect(metadata.tag(.file, "FileTypeExtension")?.displayText == "tif")
        #expect(metadata.tag(.file, "ExifByteOrder")?.value == .string("MM"))
        #expect(metadata.tag(.file, "ExifByteOrder")?.displayText == "Big-endian (Motorola, MM)")
    }

    @Test(arguments: ["basic-le", "basic-be"])
    func fileTagsMatchSnapshot(_ id: String) throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url(id))
        let snapshot = try Snapshot.load(id)
        for (raw, display) in zip(snapshot.raw, snapshot.display) where raw.group == "File" {
            let tag = try #require(metadata.tag(.file, raw.name))
            #expect(tag.value.exiftoolText == Conformance.text(raw.value))
            #expect(tag.displayText == Conformance.text(display.value))
        }
        #expect(metadata.tags.filter { $0.group == .file }.count == snapshot.raw.filter { $0.group == "File" }.count)
    }
}
