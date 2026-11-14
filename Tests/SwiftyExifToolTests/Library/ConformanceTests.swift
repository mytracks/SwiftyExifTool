import ConformanceKit
import Foundation
import Testing
import FixtureKit
@testable import SwiftyExifTool

/// Every committed TIFF fixture compared with its exiftool snapshot (exif-tags spec,
/// "Conversions match observations").
@Suite struct ConformanceTests {
    static let fixtures = FixtureCatalogue.all.filter(\.isTIFF).map(\.id)

    @Test(arguments: fixtures)
    func fixtureMatchesSnapshot(_ id: String) throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url(id))
        let mismatches = Conformance.compare(metadata, with: try Snapshot.load(id), deviations: try Deviations.load())
        #expect(mismatches.isEmpty, "\(id):\n\(mismatches.map(\.description).joined(separator: "\n"))")
    }
}

/// The comparison itself must catch differences (task 7.7).
@Suite struct ConformanceSelfTests {
    func tampered(_ metadata: Metadata, _ transform: (SwiftyExifTool.Tag) -> SwiftyExifTool.Tag) -> Metadata {
        Metadata(fileType: metadata.fileType, byteOrder: metadata.byteOrder, tags: metadata.tags.map(transform),
                 directories: metadata.directories, warnings: metadata.warnings)
    }

    @Test func wrongDisplayTextIsReported() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("tiff-orientation"))
        let wrong = tampered(metadata) { tag in
            guard tag.name == "Orientation", tag.value == .integer(6) else { return tag }
            return SwiftyExifTool.Tag(group: tag.group, name: tag.name, id: tag.id, isUnknown: tag.isUnknown, stored: tag.stored,
                                      value: tag.value, displayText: "Rotate 90 CCW", location: tag.location)
        }
        let mismatches = Conformance.compare(wrong, with: try Snapshot.load("tiff-orientation"), deviations: try Deviations.load())
        #expect(mismatches.count == 1)
        #expect(mismatches.first?.description == #"IFD5:Orientation display: expected "Rotate 90 CW", got "Rotate 90 CCW""#)
    }

    @Test func wrongValueAndMissingTagAreReported() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-le"))
        let wrongValue = tampered(metadata) { tag in
            guard tag.name == "ISO" else { return tag }
            return SwiftyExifTool.Tag(group: tag.group, name: tag.name, id: tag.id, isUnknown: false, stored: tag.stored,
                                      value: .integer(201), displayText: "201", location: tag.location)
        }
        let snapshot = try Snapshot.load("basic-le")
        #expect(Conformance.compare(wrongValue, with: snapshot, deviations: try Deviations.load()).contains { $0.key == "ExifIFD:ISO" })

        let missing = Metadata(fileType: metadata.fileType, byteOrder: metadata.byteOrder,
                               tags: metadata.tags.filter { $0.name != "Make" }, directories: [], warnings: [])
        let mismatches = Conformance.compare(missing, with: snapshot, deviations: try Deviations.load())
        #expect(mismatches.contains { $0.key == "IFD0:Make" && $0.kind == "missing" })
    }

    @Test func everyTIFFFixtureHasASnapshot() throws {
        for id in ConformanceTests.fixtures {
            #expect(throws: Never.self) { try Snapshot.load(id) }
        }
        #expect(ConformanceTests.fixtures.count > 80)
    }
}
