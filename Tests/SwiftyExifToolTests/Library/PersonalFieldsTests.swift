import ConformanceKit
import Foundation
import Testing

/// Personal fields in corpus snapshots (exiftool-conformance spec, "Personal fields are hashed").
@Suite struct PersonalFieldsTests {
    @Test func keyPatterns() {
        #expect(PersonalFields.isPersonal("IFD0:Artist"))
        #expect(PersonalFields.isPersonal("IFD0:Copyright"))
        #expect(PersonalFields.isPersonal("ExifIFD:OwnerName"))
        #expect(PersonalFields.isPersonal("ExifIFD:BodySerialNumber"))
        #expect(PersonalFields.isPersonal("ExifIFD:LensSerialNumber"))
        #expect(PersonalFields.isPersonal("GPS:GPSLatitude"))
        #expect(PersonalFields.isPersonal("GPS:GPSVersionID"))
        #expect(!PersonalFields.isPersonal("IFD0:Make"))
        #expect(!PersonalFields.isPersonal("ExifIFD:ISO"))
        #expect(!PersonalFields.isPersonal("Artist"))
    }

    @Test func canonicalNumberText() {
        #expect(PersonalFields.canonicalText(.number("48.85820000001")) == "48.8582")
        #expect(PersonalFields.canonicalText(.number("48.8582")) == "48.8582")
        #expect(PersonalFields.canonicalText(.number("1234567")) == "1234567")
        #expect(PersonalFields.canonicalText(.string("N")) == "N")
        #expect(PersonalFields.hashed(.number("48.85820000001")) == PersonalFields.hashed(.number("48.8582")))
    }

    @Test func hashedFormat() {
        let hashed = PersonalFields.hashed(.string("Jane Doe"))
        #expect(hashed.text == "sha256:" + Corpus.sha256(of: "Jane Doe"))
        #expect(PersonalFields.isHashed(hashed))
        #expect(PersonalFields.hashed(hashed) == hashed)
    }

    @Test func hashedFieldsStillCompare() {
        let ours: [Entry] = [.init(key: "IFD0:Artist", value: .string("Jane Doe")), .init(key: "IFD0:Make", value: .string("X"))]
        let snapshot: [Entry] = [.init(key: "IFD0:Artist", value: PersonalFields.hashed(.string("Jane Doe"))), .init(key: "IFD0:Make", value: .string("X"))]
        let same = Conformance.classify(raw: ours, display: ours, expectedRaw: snapshot, expectedDisplay: snapshot,
                                        prepare: PersonalFields.prepare)
        #expect(same.keys.map(\.status) == [.matching, .matching])

        let other: [Entry] = [.init(key: "IFD0:Artist", value: .string("John Doe")), .init(key: "IFD0:Make", value: .string("X"))]
        let differing = Conformance.classify(raw: other, display: other, expectedRaw: snapshot, expectedDisplay: snapshot,
                                             prepare: PersonalFields.prepare)
        #expect(differing.keys.first?.status == .differing)
    }
}
