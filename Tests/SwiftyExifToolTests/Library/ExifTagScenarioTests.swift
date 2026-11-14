import Foundation
import Testing
@testable import SwiftyExifTool

/// Explicit scenarios of the exif-tags spec (the conformance test covers the rest).
@Suite struct ExifTagScenarioTests {
    let basic = try! MetadataReader.read(contentsOf: FixtureFiles.url("basic-le"))

    @Test func tagsFromBothSpecifications() {
        #expect(basic.tag(.ifd0, "Make")?.isUnknown == false)
        #expect(basic.tag(.exifIFD, "DateTimeOriginal")?.isUnknown == false)
    }

    @Test func namesThatDifferFromTheSpecification() {
        #expect(basic.tag(.ifd0, "ImageHeight")?.id == 0x0101)
        #expect(basic.tag(.exifIFD, "ISO")?.id == 0x8827)
    }

    @Test func rationalExposureTime() throws {
        let tag = try #require(basic.tag(.exifIFD, "ExposureTime"))
        #expect(tag.stored?.contents == .rationals([Rational(1, 250)]))
        #expect(tag.value == .double(0.004))
        #expect(tag.displayText == "1/250")
    }

    @Test func enumeratedOrientationAndByteArray() throws {
        #expect(basic.tag(.ifd0, "Orientation")?.displayText == "Rotate 90 CW")
        let version = try #require(basic.tag(.gps, "GPSVersionID"))
        #expect(version.value == .string("2 3 0 0"))
        #expect(version.displayText == "2.3.0.0")
    }

    @Test func flashResolutionUnitAndGPSReference() {
        #expect(basic.tag(.exifIFD, "Flash")?.displayText == "Off, Did not fire")
        #expect(basic.tag(.ifd0, "ResolutionUnit")?.displayText == "inches")
        #expect(basic.tag(.gps, "GPSLatitudeRef")?.displayText == "North")
    }

    @Test func apexValuesAndCoordinates() throws {
        let exif = try MetadataReader.read(contentsOf: FixtureFiles.url("exif-all-tags"))
        let aperture = try #require(exif.tag(.exifIFD, "ApertureValue"))
        #expect(aperture.value == .double(pow(2, 1.5)))
        #expect(aperture.displayText == "2.8")
        #expect(exif.tag(.exifIFD, "ExposureCompensation")?.displayText == "-1/3")
        #expect(exif.tag(.exifIFD, "LensInfo")?.displayText == "24-70mm f/2.8")
        #expect(exif.tag(.exifIFD, "CFAPattern")?.displayText == "[Red,Green][Green,Blue]")

        let gps = try MetadataReader.read(contentsOf: FixtureFiles.url("gps-all-tags"))
        #expect(gps.tag(.gps, "GPSLatitude")?.displayText == #"48 deg 8' 12.34""#)
        #expect(gps.tag(.gps, "GPSTimeStamp")?.value == .string("10:20:30.5"))
    }

    @Test func exif31TagsUseSpecificationNames() throws {
        let exif = try MetadataReader.read(contentsOf: FixtureFiles.url("exif-all-tags"))
        #expect(exif.tag(.exifIFD, "NoiseReduction")?.displayText == "Normal strength noise reduction")
        #expect(exif.tag(.exifIFD, "DistortionCorrection")?.displayText == "Applied")
    }

    @Test func userCommentEncodings() throws {
        let comments = try MetadataReader.read(contentsOf: FixtureFiles.url("exif-usercomment")).tags(named: "UserComment").map(\.value)
        #expect(comments == ["Hello", "Hi", "raw", "Trailing", "Zürich", "Hi", "abc"].map { .string($0) })
    }
}
