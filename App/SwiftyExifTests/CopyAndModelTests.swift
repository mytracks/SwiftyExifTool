import Foundation
import Testing
import SwiftyExifTool
@testable import SwiftyExif

@MainActor
final class RecordingPasteboard: Pasteboard {
    var strings: [String] = []
    func setString(_ string: String) { strings.append(string) }
}

@MainActor
@Suite struct CopyTests {
    @Test func copyValueDisplayAndRow() throws {
        let pasteboard = RecordingPasteboard()
        let model = InspectorModel(pasteboard: pasteboard)
        let row = try #require(try Fixtures.file("basic-le").rows.first { $0.qualifiedName == "IFD0:Orientation" })
        model.copyValue(row)
        model.copyDisplay(row)
        model.copyRows([row])
        #expect(pasteboard.strings == ["6", "Rotate 90 CW", "IFD0:Orientation\t6\tRotate 90 CW"])
    }
}

@MainActor
@Suite struct InspectorModelTests {
    @Test func opensAFixture() async throws {
        let model = InspectorModel()
        await model.open(Fixtures.url("basic-le")).value
        let file = try #require(model.file)
        #expect(file.metadata.fileType == .tiff)
        #expect(!model.isLoading)
    }

    @Test func unsupportedFormatFails() async throws {
        let model = InspectorModel()
        await model.open(Fixtures.url("sig-png")).value
        guard case .failed(_, let error) = model.state else { Issue.record("expected failure"); return }
        #expect(error == .unsupportedFormat(.png))
        #expect(error.userMessage == "PNG is not supported.")
    }

    @Test func loadingStateWhileReading() async throws {
        let model = InspectorModel(reader: { url throws(ReadError) in
            Thread.sleep(forTimeInterval: 0.2)
            return try MetadataReader.read(contentsOf: url)
        })
        let task = model.open(Fixtures.url("basic-le"))
        #expect(model.isLoading)
        await task.value
        #expect(model.file != nil)
    }

    @Test func supersededReadIsDiscarded() async throws {
        let slow = Fixtures.url("basic-le")
        let model = InspectorModel(reader: { url throws(ReadError) in
            if url == slow { Thread.sleep(forTimeInterval: 0.3) }
            return try MetadataReader.read(contentsOf: url)
        })
        let first = model.open(slow)
        let second = model.open(Fixtures.url("subifds"))
        await second.value
        await first.value
        #expect(model.file?.displayName == "subifds.tif")
    }

    @Test func fileIsUnchanged() async throws {
        let url = Fixtures.url("basic-le")
        let before = try Data(contentsOf: url)
        let date = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        await InspectorModel().open(url).value
        #expect(try Data(contentsOf: url) == before)
        #expect(try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate == date)
    }

    @Test func displayNameOverride() async throws {
        let model = InspectorModel()
        await model.open(Fixtures.url("basic-le"), displayName: "Dropped.NEF").value
        #expect(model.file?.displayName == "Dropped.NEF")
    }

    @Test func openingResetsTheQuery() async {
        let model = InspectorModel()
        model.query.searchText = "x"
        await model.open(Fixtures.url("basic-le")).value
        #expect(model.query == TagQuery())
    }
}
