import Foundation

/// Fixtures for the Exif, GPS and Interoperability tags of CIPA DC-008-2026 (Exif 3.1).
extension TagFixtures {
    typealias R = TIFFBuilder.Rational
    typealias S = TIFFBuilder.SRational
    typealias Entry = TIFFBuilder.Entry
    typealias IFD = TIFFBuilder.IFD

    static func bytes(_ s: String) -> [UInt8] { Array(s.utf8) }

    /// Every Exif IFD tag (4.6.6) with a typical value of its specified type.
    static let exifAllTags = TIFFBuilder(.little, chain: [IFD([.exif(IFD([
        .rational(0x829A, 1, 250),
        .rational(0x829D, 28, 10),
        .short(0x8822, 2),
        .ascii(0x8824, "Spectral"),
        .short(0x8827, 200),
        .undefined(0x8828, [0, 2, 0, 1, 0x41, 0x42, 0, 0, 0, 1, 0, 0, 0, 2]),
        .short(0x8830, 2),
        .long(0x8831, 200),
        .long(0x8832, 210),
        .long(0x8833, 220),
        .long(0x8834, 230),
        .long(0x8835, 240),
        .undefined(0x9000, bytes("0232")),
        .ascii(0x9003, "2026:11:14 10:00:00"),
        .ascii(0x9004, "2026:11:14 10:00:01"),
        .ascii(0x9010, "+01:00"),
        .ascii(0x9011, "+02:00"),
        .ascii(0x9012, "-03:30"),
        .undefined(0x9101, [1, 2, 3, 0]),
        .rational(0x9102, 4, 1),
        .srational(0x9201, 8, 1),
        .rational(0x9202, 3, 1),
        .srational(0x9203, 5, 2),
        .srational(0x9204, -1, 3),
        .rational(0x9205, 3, 1),
        .rational(0x9206, 25, 10),
        .short(0x9207, 5),
        .short(0x9208, 1),
        .short(0x9209, 16),
        .rational(0x920A, 50, 1),
        .shorts(0x9214, [100, 200, 50, 40]),
        .undefined(0x9286, bytes("ASCII\0\0\0Hello world")),
        .undefined(0x9287, [0, 2, 1, 1, 4, 0]),
        .ascii(0x9290, "123"),
        .ascii(0x9291, "45"),
        .ascii(0x9292, "6"),
        .srational(0x9400, 215, 10),
        .rational(0x9401, 50, 1),
        .rational(0x9402, 1013, 1),
        .srational(0x9403, -5, 1),
        .rational(0x9404, 98, 100),
        .srational(0x9405, -10, 1),
        .undefined(0xA000, bytes("0100")),
        .short(0xA001, 1),
        .long(0xA002, 6000),
        .long(0xA003, 4000),
        .ascii(0xA004, "DSC00001.WAV"),
        .rational(0xA20B, 10, 1),
        .undefined(0xA20C, [0, 2, 0, 1, 0x41, 0, 0x42, 0, 0, 0, 0, 1, 0, 0, 0, 2]),
        .rational(0xA20E, 4000, 1),
        .rational(0xA20F, 4000, 1),
        .short(0xA210, 3),
        .shorts(0xA214, [100, 200]),
        .rational(0xA215, 200, 1),
        .short(0xA217, 2),
        .undefined(0xA300, [3]),
        .undefined(0xA301, [1]),
        .undefined(0xA302, [0, 2, 0, 2, 0, 1, 1, 2]),
        .short(0xA401, 0),
        .short(0xA402, 0),
        .short(0xA403, 0),
        .rational(0xA404, 1, 1),
        .short(0xA405, 75),
        .short(0xA406, 0),
        .short(0xA407, 0),
        .short(0xA408, 0),
        .short(0xA409, 0),
        .short(0xA40A, 0),
        .undefined(0xA40B, [0, 1, 0, 1, 0x41, 0, 0, 0]),
        .short(0xA40C, 0),
        .short(0xA40D, 0x0101),
        .utf8(0xA40E, "Straight"),
        .short(0xA40F, 1),
        .short(0xA410, 1),
        .short(0xA411, 1),
        .short(0xA412, 2),
        .ascii(0xA420, "0123456789abcdef0123456789abcdef"),
        .ascii(0xA430, "Owner"),
        .ascii(0xA431, "SN123"),
        .rationals(0xA432, [R(24, 1), R(70, 1), R(28, 10), R(28, 10)]),
        .ascii(0xA433, "LensMaker"),
        .ascii(0xA434, "Lens 24-70"),
        .ascii(0xA435, "LSN456"),
        .ascii(0xA436, "Title"),
        .ascii(0xA437, "Photographer"),
        .ascii(0xA438, "Editor"),
        .ascii(0xA439, "FW 1.0"),
        .ascii(0xA43A, "RAW Dev"),
        .ascii(0xA43B, "Edit SW"),
        .ascii(0xA43C, "Meta SW"),
        .short(0xA460, 1),
        .shorts(0xA461, [2, 2]),
        .undefined(0xA462, [0, 0, 0, 0, 0, 0, 0, 0]),
        .rational(0xA500, 22, 10),
    ]))])])

    /// Enumerated Exif tags with every value 4.6.6 defines.
    static let exifEnumerations: [Fixture] = [
        enumeration("exif-exposureprogram", tag: 0x8822, values: Array(0 ... 8), purpose: "ExposureProgram values (Exif 3.1, 4.6.6.7.3)"),
        enumeration("exif-sensitivitytype", tag: 0x8830, values: Array(0 ... 7), purpose: "SensitivityType values (Exif 3.1, 4.6.6.7.7)"),
        enumeration("exif-meteringmode", tag: 0x9207, values: [0, 1, 2, 3, 4, 5, 6, 255], purpose: "MeteringMode values (Exif 3.1, 4.6.6.7.19)"),
        enumeration("exif-lightsource", tag: 0x9208, values: [0, 1, 2, 3, 4] + Array(9 ... 34) + [255],
                    purpose: "LightSource values (Exif 3.1, 4.6.6.7.20)"),
        enumeration("exif-flash", tag: 0x9209,
                    values: [0x00, 0x01, 0x05, 0x07, 0x08, 0x09, 0x0D, 0x0F, 0x10, 0x14, 0x18, 0x19, 0x1D, 0x1F, 0x20,
                             0x30, 0x41, 0x45, 0x47, 0x49, 0x4D, 0x4F, 0x50, 0x58, 0x59, 0x5D, 0x5F],
                    purpose: "Flash bit combinations (Exif 3.1, 4.6.6.7.21, Figure 19)"),
        enumeration("exif-colorspace", tag: 0xA001, values: [1, 0xFFFF], purpose: "ColorSpace values (Exif 3.1, 4.6.6.2.1)"),
        enumeration("exif-focalplaneresolutionunit", tag: 0xA210, values: [1, 2, 3], purpose: "FocalPlaneResolutionUnit values (Exif 3.1, 4.6.6.7.28)"),
        enumeration("exif-sensingmethod", tag: 0xA217, values: [1, 2, 3, 4, 5, 7, 8], purpose: "SensingMethod values (Exif 3.1, 4.6.6.7.31)"),
        enumeration("exif-customrendered", tag: 0xA401, values: [0, 1], purpose: "CustomRendered values (Exif 3.1, 4.6.6.7.35)"),
        enumeration("exif-exposuremode", tag: 0xA402, values: [0, 1, 2], purpose: "ExposureMode values (Exif 3.1, 4.6.6.7.36)"),
        enumeration("exif-whitebalance", tag: 0xA403, values: [0, 1], purpose: "WhiteBalance values (Exif 3.1, 4.6.6.7.37)"),
        enumeration("exif-scenecapturetype", tag: 0xA406, values: [0, 1, 2, 3], purpose: "SceneCaptureType values (Exif 3.1, 4.6.6.7.40)"),
        enumeration("exif-gaincontrol", tag: 0xA407, values: [0, 1, 2, 3, 4], purpose: "GainControl values (Exif 3.1, 4.6.6.7.41)"),
        enumeration("exif-contrast", tag: 0xA408, values: [0, 1, 2], purpose: "Contrast values (Exif 3.1, 4.6.6.7.42)"),
        enumeration("exif-saturation", tag: 0xA409, values: [0, 1, 2], purpose: "Saturation values (Exif 3.1, 4.6.6.7.43)"),
        enumeration("exif-sharpness", tag: 0xA40A, values: [0, 1, 2], purpose: "Sharpness values (Exif 3.1, 4.6.6.7.44)"),
        enumeration("exif-subjectdistancerange", tag: 0xA40C, values: [0, 1, 2, 3], purpose: "SubjectDistanceRange values (Exif 3.1, 4.6.6.7.46)"),
        enumeration("exif-developmenttype", tag: 0xA40D, values: [0x0101, 0x0102, 0x0104, 0x0201, 0x0202, 0x0204, 0x0401, 0x0402, 0x0404],
                    purpose: "DevelopmentType index combinations (Exif 3.1, 4.6.6.7.47, Figure 26)"),
        enumeration("exif-distortioncorrection", tag: 0xA40F, values: [0, 1], purpose: "DistortionCorrection values (Exif 3.1, 4.6.6.7.49)"),
        enumeration("exif-noisereduction", tag: 0xA412, values: [0, 1, 2, 3], purpose: "NoiseReduction values (Exif 3.1, 4.6.6.7.52)"),
        enumeration("exif-compositeimage", tag: 0xA460, values: [0, 1, 2, 3], purpose: "CompositeImage values (Exif 3.1, 4.6.6.7.53)"),
        Fixture("exif-filesource-scenetype", "FileSource and SceneType values (Exif 3.1, 4.6.6.7.32-33)", .tiff(TIFFBuilder(.little, chain:
            [0, 1, 2, 3].map { IFD([.undefined(0xA300, [UInt8($0)]), .undefined(0xA301, [1])]) }))),
        Fixture("exif-components", "ComponentsConfiguration combinations (Exif 3.1, 4.6.6.3.3)", .tiff(TIFFBuilder(.little, chain:
            [[1, 2, 3, 0], [4, 5, 6, 0], [0, 0, 0, 0]].map { IFD([.undefined(0x9101, $0)]) }))),
        Fixture("exif-usercomment", "UserComment character codes (Exif 3.1, 4.6.4)", .tiff(TIFFBuilder(.little, chain: [
            IFD([.undefined(0x9286, bytes("ASCII\0\0\0Hello"))]),
            IFD([.undefined(0x9286, bytes("UNICODE\0") + [0x00, 0x48, 0x00, 0x69])]),
            IFD([.undefined(0x9286, [UInt8](repeating: 0, count: 8) + bytes("raw   "))]),
            IFD([.undefined(0x9286, bytes("ASCII\0\0\0Trailing   "))]),
            IFD([.undefined(0x9286, bytes("UNICODE\0") + bytes("Zürich"))]),
            IFD([.undefined(0x9286, bytes("UNICODE\0") + [0x48, 0x00, 0x69, 0x00])]),
            IFD([.undefined(0x9286, bytes("JIS\0\0\0\0\0") + bytes("abc"))]),
        ]))),
        Fixture("exif-versions", "ExifVersion and FlashpixVersion strings (Exif 3.1, 4.6.6.1)", .tiff(TIFFBuilder(.little, chain:
            ["0232", "0300", "0310", "0100"].map { IFD([.undefined(0x9000, bytes($0)), .undefined(0xA000, bytes($0))]) }))),
        Fixture("exif-exposuretimes", "ExposureTime and ShutterSpeedValue formatting", .tiff(TIFFBuilder(.little, chain:
            [R(1, 8000), R(1, 250), R(1, 3), R(10, 32), R(1, 4), R(4, 10), R(1, 2), R(1, 1), R(13, 10), R(2, 1), R(30, 1), R(0, 1)].map {
                IFD([.rationals(0x829A, [$0])])
            } + [S(13, 1), S(8, 1), S(0, 1), S(-2, 1), S(5, 3)].map { IFD([.srationals(0x9201, [$0])]) }))),
        Fixture("exif-apertures", "FNumber, ApertureValue and MaxApertureValue formatting", .tiff(TIFFBuilder(.little, chain:
            [R(28, 10), R(1, 1), R(56, 10), R(22, 1), R(35, 10), R(0, 1)].map { IFD([.rationals(0x829D, [$0])]) } +
            [R(3, 1), R(0, 1), R(497, 100), R(1, 3)].map { IFD([.rationals(0x9202, [$0]), .rationals(0x9205, [$0])]) }))),
        Fixture("exif-bias-brightness", "ExposureBiasValue and BrightnessValue formatting", .tiff(TIFFBuilder(.little, chain:
            [S(0, 1), S(1, 3), S(-1, 3), S(2, 3), S(-2, 3), S(1, 2), S(-1, 2), S(1, 1), S(-5, 3), S(3, 10), S(7, 6)].map {
                IFD([.srationals(0x9204, [$0]), .srationals(0x9203, [$0])])
            }))),
        Fixture("exif-lengths-distances", "FocalLength, SubjectDistance, FocalLengthIn35mmFilm and DigitalZoomRatio formatting", .tiff(TIFFBuilder(.little, chain:
            [(R(50, 1), R(25, 10), 75 as UInt16, R(1, 1)), (R(185, 10), R(0, 1), 0, R(0, 1)), (R(4, 3), R(0xFFFF_FFFF, 1), 28, R(15, 10)),
             (R(0, 1), R(1, 3), 1000, R(3, 1))].map {
                IFD([.rationals(0x920A, [$0.0]), .rationals(0x9206, [$0.1]), .short(0xA405, $0.2), .rationals(0xA404, [$0.3])])
            }))),
        Fixture("exif-lensspecification", "LensSpecification formatting", .tiff(TIFFBuilder(.little, chain:
            [[R(24, 1), R(70, 1), R(28, 10), R(28, 10)], [R(50, 1), R(50, 1), R(18, 10), R(18, 10)],
             [R(18, 1), R(55, 1), R(35, 10), R(56, 10)], [R(0, 0), R(0, 0), R(0, 0), R(0, 0)]].map { IFD([.rationals(0xA432, $0)]) }))),
        Fixture("exif-subjectarea", "SubjectArea and SubjectLocation with 2, 3 and 4 values", .tiff(TIFFBuilder(.little, chain: [
            IFD([.shorts(0x9214, [100, 200]), .shorts(0xA214, [10, 20])]),
            IFD([.shorts(0x9214, [100, 200, 50])]),
            IFD([.shorts(0x9214, [100, 200, 50, 40])]),
        ]))),
        Fixture("exif-environment", "Temperature, Humidity, Pressure, WaterDepth, Acceleration and CameraElevationAngle", .tiff(TIFFBuilder(.little, chain: [
            IFD([.srational(0x9400, 215, 10), .rational(0x9401, 50, 1), .rational(0x9402, 1013, 1),
                 .srational(0x9403, -5, 1), .rational(0x9404, 98, 100), .srational(0x9405, -10, 1)]),
            IFD([.srational(0x9400, -3, 1), .rational(0x9401, 0, 1), .rational(0x9402, 0xFFFF_FFFF, 1),
                 .srational(0x9403, 2, 1), .rational(0x9404, 0, 1), .srational(0x9405, 45, 1)]),
        ]))),
        Fixture("exif-misc-rationals", "CompressedBitsPerPixel, FlashEnergy, FocalPlane resolutions, ExposureIndex and Gamma", .tiff(TIFFBuilder(.little, chain: [
            IFD([.rational(0x9102, 4, 1), .rational(0xA20B, 10, 1), .rational(0xA20E, 4000, 1), .rational(0xA20F, 3000, 1),
                 .rational(0xA215, 200, 1), .rational(0xA500, 22, 10)]),
            IFD([.rational(0x9102, 1, 3), .rational(0xA20B, 0, 1), .rational(0xA20E, 10000, 3), .rational(0xA20F, 1, 0),
                 .rational(0xA215, 125, 10), .rational(0xA500, 1, 1)]),
        ]))),
        Fixture("exif-learningoptoutin", "LearningOptOutIn sets (Exif 3.1, 4.6.6.4.3)", .tiff(TIFFBuilder(.little, chain: [
            IFD([.undefined(0x9287, [0, 2])]),
            IFD([.undefined(0x9287, [0, 2, 1, 1, 4, 0])]),
        ]))),
        Fixture("exif-cfapattern", "CFAPattern layouts (Exif 3.1, 4.6.6.7.34)", .tiff(TIFFBuilder(.little, chain: [
            IFD([.undefined(0xA302, [0, 2, 0, 2, 0, 1, 1, 2])]),
            IFD([.undefined(0xA302, [2, 0, 2, 0, 1, 2, 0, 1])]),
        ]))),
    ]

    // MARK: GPS (4.6.7)

    static let gpsAllTags = TIFFBuilder(.little, chain: [IFD([.gps(IFD([
        .byte(0x0000, [2, 3, 0, 0]),
        .ascii(0x0001, "N"),
        .rationals(0x0002, [R(48, 1), R(8, 1), R(1234, 100)]),
        .ascii(0x0003, "E"),
        .rationals(0x0004, [R(11, 1), R(34, 1), R(5678, 100)]),
        .byte(0x0005, [0]),
        .rational(0x0006, 5195, 10),
        .rationals(0x0007, [R(10, 1), R(20, 1), R(305, 10)]),
        .ascii(0x0008, "07"),
        .ascii(0x0009, "A"),
        .ascii(0x000A, "3"),
        .rational(0x000B, 15, 10),
        .ascii(0x000C, "K"),
        .rational(0x000D, 50, 1),
        .ascii(0x000E, "T"),
        .rational(0x000F, 1805, 10),
        .ascii(0x0010, "M"),
        .rational(0x0011, 90, 1),
        .ascii(0x0012, "WGS-84"),
        .ascii(0x0013, "S"),
        .rationals(0x0014, [R(33, 1), R(52, 1), R(0, 1)]),
        .ascii(0x0015, "W"),
        .rationals(0x0016, [R(151, 1), R(12, 1), R(30, 1)]),
        .ascii(0x0017, "T"),
        .rational(0x0018, 45, 1),
        .ascii(0x0019, "N"),
        .rational(0x001A, 12, 1),
        .undefined(0x001B, bytes("ASCII\0\0\0GPS")),
        .undefined(0x001C, bytes("ASCII\0\0\0Munich")),
        .ascii(0x001D, "2026:11:14"),
        .short(0x001E, 1),
        .rational(0x001F, 5, 1),
    ]))])])

    /// One GPS directory per fixture: GPS tags cannot be chained like main-table tags.
    static func gps(_ id: String, _ purpose: String, _ entries: [Entry]) -> Fixture {
        Fixture(id, purpose, .tiff(TIFFBuilder(.little, chain: [IFD([.gps(IFD(entries))])])))
    }

    static let gpsFixtures: [Fixture] = [
        gps("gps-refs-1", "GPS reference values, first set (Exif 3.1, 4.6.7)", [
            .ascii(0x0001, "S"), .ascii(0x0003, "W"), .byte(0x0005, [1]), .ascii(0x0009, "V"), .ascii(0x000A, "2"),
            .ascii(0x000C, "M"), .ascii(0x000E, "M"), .ascii(0x0010, "T"), .ascii(0x0013, "N"), .ascii(0x0015, "E"),
            .ascii(0x0017, "M"), .ascii(0x0019, "K"), .short(0x001E, 0),
        ]),
        gps("gps-refs-2", "GPS reference values, second set (Exif 3.1, 4.6.7)", [
            .byte(0x0005, [2]), .ascii(0x000C, "N"), .ascii(0x0019, "M"),
        ]),
        gps("gps-refs-3", "GPS reference values, third set (Exif 3.1, 4.6.7)", [
            .byte(0x0005, [3]),
        ]),
        gps("gps-timestamp-small", "GPSTimeStamp with single-digit fields", [
            .rationals(0x0007, [R(1, 1), R(2, 1), R(3, 1)]),
        ]),
        gps("gps-timestamp-fraction", "GPSTimeStamp with fractional minutes and seconds", [
            .rationals(0x0007, [R(9, 1), R(5, 2), R(525, 100)]),
        ]),
        gps("gps-coordinates", "GPS coordinate and time formatting edge cases", [
            .rationals(0x0002, [R(48, 1), R(812, 100), R(0, 1)]),
            .rationals(0x0004, [R(0, 1), R(0, 1), R(1, 3)]),
            .rational(0x0006, 0, 1),
            .rationals(0x0007, [R(23, 1), R(59, 1), R(5999, 100)]),
            .rationals(0x0014, [R(4812345, 100000), R(0, 1), R(0, 1)]),
        ]),
    ]

    // MARK: Interoperability (4.6.8)

    static let interopFixtures: [Fixture] = [
        Fixture("interop-index", "InteroperabilityIndex values (Exif 3.1, 4.6.8.1.1)", .tiff(TIFFBuilder(.little, chain: [
            IFD([.exif(IFD([.interop(IFD([.ascii(0x0001, "R98")]))]))]),
            IFD([.ascii(0x0001, "THM")]),
            IFD([.ascii(0x0001, "R03")]),
        ]))),
    ]

    /// Every ASCII tag with a value ending in spaces: which tags exiftool trims.
    static let mainASCIITags: [UInt16] = [
        0x010D, 0x010E, 0x010F, 0x0110, 0x011D, 0x0131, 0x0132, 0x013B, 0x013C, 0x014D, 0x0151, 0x8298,
        0x8824, 0x9003, 0x9004, 0x9010, 0x9011, 0x9012, 0x9290, 0x9291, 0x9292, 0xA004, 0xA420, 0xA430, 0xA431,
        0xA433, 0xA434, 0xA435, 0xA436, 0xA437, 0xA438, 0xA439, 0xA43A, 0xA43B, 0xA43C,
    ]
    static let gpsASCIITags: [UInt16] = [
        0x0001, 0x0003, 0x0008, 0x0009, 0x000A, 0x000C, 0x000E, 0x0010, 0x0012, 0x0013, 0x0015, 0x0017, 0x0019, 0x001D,
    ]
    static let asciiTrailingSpaces = Fixture("ascii-trailing-spaces", "Every ASCII tag with trailing spaces before the NUL",
        .tiff(TIFFBuilder(.little, chain: [IFD(mainASCIITags.map { .ascii($0, "X  ") } + [.gps(IFD(gpsASCIITags.map { .ascii($0, "X  ") }))])])))

    static let exif: [Fixture] =
        [Fixture("exif-all-tags", "Every Exif IFD tag of Exif 3.1 (4.6.6) with a typical value", .tiff(exifAllTags)),
         Fixture("gps-all-tags", "Every GPS tag of Exif 3.1 (4.6.7) with a typical value", .tiff(gpsAllTags))]
        + exifEnumerations + gpsFixtures + interopFixtures + [asciiTrailingSpaces]
}
