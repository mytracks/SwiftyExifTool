import Testing
import SwiftyExifTool
@testable import SwiftyExif

@Suite struct TagQueryTests {
    let rows = try! Fixtures.file("basic-le").rows

    func names(_ query: TagQuery, _ rows: [TagRow]? = nil) -> [String] {
        query.sections(for: rows ?? self.rows).flatMap(\.rows).map(\.qualifiedName)
    }

    @Test func noQueryShowsEverything() {
        #expect(names(TagQuery()).count == rows.count)
        #expect(!TagQuery().isFiltering)
    }

    @Test func searchByDisplayText() {
        #expect(names(TagQuery(searchText: "rotate")) == ["IFD0:Orientation"])
        #expect(TagQuery(searchText: "rotate").sections(for: rows).map(\.group) == [.ifd0])
    }

    @Test func searchByID() {
        #expect(names(TagQuery(searchText: "0x829a")) == ["ExifIFD:ExposureTime"])
    }

    @Test func searchByNameAndValue() {
        #expect(names(TagQuery(searchText: "iso")).contains("ExifIFD:ISO"))
        #expect(names(TagQuery(searchText: "TestCam")) == ["IFD0:Make"])
    }

    @Test func groupFilter() {
        let query = TagQuery(groups: [.gps])
        #expect(names(query) == ["GPS:GPSVersionID", "GPS:GPSLatitudeRef"])
        #expect(query.isFiltering)
    }

    @Test func hideUnknownTags() throws {
        let unknown = try Fixtures.file("unknown-tags").rows
        let shown = names(TagQuery(hideUnknown: true), unknown)
        #expect(!shown.contains { $0.hasSuffix("Exif_0xc0de") || $0.hasSuffix("Exif_0x0077") || $0.hasSuffix("GPS_0x0077") })
        #expect(shown.contains("IFD0:ImageWidth"))
    }

    @Test func filtersCombineWithSearch() {
        #expect(names(TagQuery(searchText: "ImageWidth", groups: [.ifd1])) == ["IFD1:ImageWidth"])
    }
}
