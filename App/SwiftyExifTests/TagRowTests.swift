import Foundation
import Testing
import SwiftyExifTool
@testable import SwiftyExif

@Suite struct TagRowTests {
    let file = try! Fixtures.file("basic-le")

    @Test func orientationRow() throws {
        let row = try #require(file.rows.first { $0.qualifiedName == "IFD0:Orientation" })
        #expect(row.idText == "0x0112")
        #expect(row.typeText == "SHORT")
        #expect(row.countText == "1")
        #expect(row.valueText == "6")
        #expect(row.displayText == "Rotate 90 CW")
        #expect(row.offsetText == row.tag.location.map { String($0.valueOffset) })
        #expect(row.offsetText != nil)
    }

    @Test func fileGroupRowsComeFirstWithoutStructureInfo() throws {
        #expect(file.groups.first?.group == .file)
        let fileRows = file.rows.filter { $0.group == .file }
        #expect(fileRows.count == 4)
        for row in fileRows {
            #expect(row.idText == nil && row.typeText == nil && row.countText == nil && row.offsetText == nil)
        }
    }

    @Test func summary() {
        #expect(file.fileTypeText == "TIFF")
        #expect(file.byteOrderText.hasPrefix("Little-endian"))
        #expect(file.tagCount == file.metadata.tags.count)
        #expect(file.directoryCount == 4)
        #expect(file.warningCount == 0)
        #expect(file.displayName == "basic-le.tif")
        #expect(file.fileSize == (try? Data(contentsOf: file.url).count))
    }

    @Test func groupsInFirstOccurrenceOrder() {
        #expect(file.groups.map(\.group) == [.file, .ifd0, .exifIFD, .gps, .ifd1])
    }

    @Test func storedValueDescriptions() throws {
        let exposure = try #require(file.rows.first { $0.name == "ExposureTime" })
        #expect(exposure.tag.stored.map(StoredValueText.describe) == "1/250")
        #expect(exposure.valueText == "0.004")
        let make = try #require(file.rows.first { $0.name == "Make" })
        #expect(make.tag.stored.map(StoredValueText.describe) == #""TestCam\0""#)
        let large = try Fixtures.file("large-undefined")
        let blob = try #require(large.rows.first { $0.tag.id == 0xF001 })
        #expect(blob.tag.stored.map(StoredValueText.describe)?.hasPrefix("Not loaded") == true)
    }

    @Test func unknownTagIsFlagged() throws {
        let unknown = try Fixtures.file("unknown-tags")
        #expect(unknown.rows.first { $0.name == "Exif_0xc0de" }?.isUnknown == true)
    }
}
