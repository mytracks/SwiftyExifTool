import ConformanceKit
import FixtureKit
import Foundation
import Testing
@testable import SwiftyExifTool

/// exiftool-shaped output and the comparison on entries (exiftool-conformance spec).
@Suite struct ExiftoolOutputTests {
    func entries(_ id: String, numeric: Bool) throws -> [ConformanceKit.Entry] {
        ExiftoolOutput.entries(try MetadataReader.read(contentsOf: FixtureFiles.url(id)), numeric: numeric)
    }

    func value(_ entries: [ConformanceKit.Entry], _ key: String) -> JSONValue? {
        entries.first { $0.key == key }?.value
    }

    @Test func numericAndDisplayOutput() throws {
        let raw = try entries("basic-le", numeric: true)
        let display = try entries("basic-le", numeric: false)
        #expect(value(raw, "IFD0:Orientation") == .number("6"))
        #expect(value(display, "IFD0:Orientation") == .string("Rotate 90 CW"))
        #expect(value(raw, "IFD0:ImageWidth") == .number("640"))
        #expect(value(display, "IFD0:ImageWidth") == .number("640"))
    }

    @Test func rationalShownAsFraction() throws {
        #expect(value(try entries("basic-le", numeric: false), "ExifIFD:ExposureTime") == .string("1/250"))
        #expect(value(try entries("basic-le", numeric: true), "ExifIFD:ExposureTime") == .number("0.004"))
    }

    @Test(arguments: ConformanceTests.fixtures)
    func noFileSystemGroup(_ id: String) throws {
        for numeric in [true, false] {
            let keys = try entries(id, numeric: numeric).map(\.key)
            #expect(!keys.contains { $0.hasPrefix("System:") || $0.hasPrefix("Composite:") || $0 == "SourceFile" })
        }
    }

    @Test func matchesExiftoolOnAFixture() throws {
        let raw = try entries("basic-le", numeric: true)
        let expected = try Snapshot.load("basic-le").rawEntries
        #expect(raw.map(\.key) == expected.map(\.key))
        for (ours, theirs) in zip(raw, expected) {
            #expect(Conformance.valuesMatch(theirs.value, ours.value), "\(ours.key): \(ours.value) vs \(theirs.value)")
        }
    }

    @Test func numberGrammar() {
        #expect(JSONValue(text: "640") == .number("640"))
        #expect(JSONValue(text: "-1.5e3") == .number("-1.5e3"))
        #expect(JSONValue(text: "0230") == .string("0230"))
        #expect(JSONValue(text: "2.3.0.0") == .string("2.3.0.0"))
        #expect(JSONValue(text: "1/250") == .string("1/250"))
    }

    @Test func jsonText() throws {
        let json = ExiftoolOutput.json([.init(key: "IFD0:Make", value: .string("A \"B\"/C")), .init(key: "IFD0:ImageWidth", value: .number("640"))])
        #expect(json == "[{\n  \"IFD0:Make\": \"A \\\"B\\\"/C\",\n  \"IFD0:ImageWidth\": 640\n}]\n")
        let parsed = try OrderedJSON.parseFirstObject(json)
        #expect(parsed.map(\.key) == ["IFD0:Make", "IFD0:ImageWidth"])
    }

    @Test func repeatedKeysArePairedByOccurrence() {
        let expected: [ConformanceKit.Entry] = [.init(key: "IFD0:X", value: .number("1")), .init(key: "IFD0:X", value: .number("2"))]
        let same = Conformance.classify(raw: expected, display: expected, expectedRaw: expected, expectedDisplay: expected)
        #expect(same.keys.map(\.status) == [.matching, .matching])
        #expect(same.keys.map(\.occurrence) == [0, 1])

        let swapped: [ConformanceKit.Entry] = [.init(key: "IFD0:X", value: .number("2")), .init(key: "IFD0:X", value: .number("1"))]
        let differing = Conformance.classify(raw: swapped, display: swapped, expectedRaw: expected, expectedDisplay: expected)
        #expect(differing.keys.map(\.status) == [.differing, .differing])

        let one = Array(expected.prefix(1))
        let missing = Conformance.classify(raw: one, display: one, expectedRaw: expected, expectedDisplay: expected)
        #expect(missing.keys.map(\.status) == [.matching, .missing])
        #expect(missing.keys.last?.occurrence == 1)
    }

    @Test func latin1ArtistIsADeviation() throws {
        let metadata = try MetadataReader.read(contentsOf: FixtureFiles.url("strings"))
        let snapshot = try Snapshot.load("strings")
        let withoutDeviations = Conformance.compare(metadata, with: snapshot, deviations: Deviations(items: []))
        #expect(withoutDeviations.contains { $0.key == "IFD0:Artist" })
        let mismatches = Conformance.compare(metadata, with: snapshot, deviations: try Deviations.load())
        #expect(!mismatches.contains { $0.key == "IFD0:Artist" })
    }
}
