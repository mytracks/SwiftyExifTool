import Foundation

/// Fixtures that cover tag definitions and their conversions.
///
/// Only tag IDs from published specifications appear here
/// (docs/clean-room.md, "Allowed sources").
public enum TagFixtures {
    static let all: [Fixture] = tiff + exif

    /// A fixture that stores each value of one enumerated tag in its own
    /// chained IFD (IFD0, IFD1, …), relying on the shared main table.
    static func enumeration(_ id: String, tag: UInt16, type: TIFFBuilder.FieldType = .short, values: [UInt32],
                            purpose: String) -> Fixture {
        let chain = values.map { value -> TIFFBuilder.IFD in
            switch type {
            case .long: TIFFBuilder.IFD([.long(tag, value)])
            default: TIFFBuilder.IFD([.short(tag, UInt16(value))])
            }
        }
        return Fixture(id, purpose, .tiff(TIFFBuilder(.little, chain: chain)))
    }

    // MARK: TIFF 6.0 (Appendix A)

    static let tiffAllTags = TIFFBuilder(.little, chain: [TIFFBuilder.IFD([
        .long(0x00FE, 0),
        .short(0x00FF, 1),
        .short(0x0100, 640),
        .short(0x0101, 480),
        .shorts(0x0102, [8, 8, 8]),
        .short(0x0103, 1),
        .short(0x0106, 2),
        .short(0x0107, 1),
        .short(0x0108, 4),
        .short(0x0109, 4),
        .short(0x010A, 1),
        .ascii(0x010D, "Document"),
        .ascii(0x010E, "Description"),
        .ascii(0x010F, "Make"),
        .ascii(0x0110, "Model"),
        .longs(0x0111, [1000, 2000]),
        .short(0x0112, 1),
        .short(0x0115, 3),
        .long(0x0116, 64),
        .longs(0x0117, [500, 600]),
        .shorts(0x0118, [0, 0, 0]),
        .shorts(0x0119, [255, 255, 255]),
        .rational(0x011A, 72, 1),
        .rational(0x011B, 72, 1),
        .short(0x011C, 1),
        .ascii(0x011D, "Page"),
        .rational(0x011E, 1, 2),
        .rational(0x011F, 3, 4),
        .long(0x0120, 4096),
        .long(0x0121, 128),
        .short(0x0122, 2),
        .shorts(0x0123, [0, 100, 200, 300]),
        .long(0x0124, 0),
        .long(0x0125, 0),
        .short(0x0128, 2),
        .shorts(0x0129, [1, 3]),
        .shorts(0x012D, [0, 1, 2, 3]),
        .ascii(0x0131, "Software 1.0"),
        .ascii(0x0132, "2026:11:14 10:00:00"),
        .ascii(0x013B, "Artist"),
        .ascii(0x013C, "Host"),
        .short(0x013D, 1),
        .rationals(0x013E, [.init(313, 1000), .init(329, 1000)]),
        .rationals(0x013F, [.init(64, 100), .init(33, 100), .init(30, 100), .init(60, 100), .init(15, 100), .init(6, 100)]),
        .shorts(0x0140, [0, 1, 2, 3, 4, 5]),
        .shorts(0x0141, [10, 245]),
        .long(0x0142, 256),
        .long(0x0143, 256),
        .longs(0x0144, [3000, 4000]),
        .longs(0x0145, [100, 200]),
        .short(0x014C, 1),
        .ascii(0x014D, "Cyan"),
        .short(0x014E, 4),
        .shorts(0x0150, [0, 255]),
        .ascii(0x0151, "Printer"),
        .shorts(0x0152, [1]),
        .shorts(0x0153, [1, 1, 1]),
        .shorts(0x0154, [0, 0, 0]),
        .shorts(0x0155, [255, 255, 255]),
        .shorts(0x0156, [0, 255, 0, 255, 0, 255]),
        .short(0x0200, 1),
        .long(0x0201, 5000),
        .long(0x0202, 6000),
        .short(0x0203, 0),
        .shorts(0x0205, [1, 1, 1]),
        .shorts(0x0206, [0, 0, 0]),
        .longs(0x0207, [7000, 7100, 7200]),
        .longs(0x0208, [7300, 7400, 7500]),
        .longs(0x0209, [7600, 7700, 7800]),
        .rationals(0x0211, [.init(299, 1000), .init(587, 1000), .init(114, 1000)]),
        .shorts(0x0212, [2, 1]),
        .short(0x0213, 1),
        .longs(0x0214, [0, 255, 128, 255, 128, 255]),
        .ascii(0x8298, "Copyright"),
    ])])

    static let tiff: [Fixture] = [
        Fixture("tiff-all-tags", "Every TIFF 6.0 tag of Appendix A with a typical value", .tiff(tiffAllTags)),
        enumeration("tiff-newsubfiletype", tag: 0x00FE, type: .long, values: [0, 1, 2, 3, 4, 5, 6, 7],
                    purpose: "NewSubfileType flag combinations (TIFF 6.0 Section 8)"),
        enumeration("tiff-subfiletype", tag: 0x00FF, values: [1, 2, 3], purpose: "SubfileType values (TIFF 6.0 Section 8)"),
        enumeration("tiff-compression", tag: 0x0103, values: [1, 2, 3, 4, 5, 6, 32773],
                    purpose: "Compression values (TIFF 6.0 Appendix A)"),
        enumeration("tiff-photometric", tag: 0x0106, values: [0, 1, 2, 3, 4, 5, 6, 8],
                    purpose: "PhotometricInterpretation values (TIFF 6.0 Appendix A)"),
        enumeration("tiff-threshholding", tag: 0x0107, values: [1, 2, 3], purpose: "Threshholding values (TIFF 6.0 Section 8)"),
        enumeration("tiff-fillorder", tag: 0x010A, values: [1, 2], purpose: "FillOrder values (TIFF 6.0 Section 8)"),
        enumeration("tiff-orientation", tag: 0x0112, values: [1, 2, 3, 4, 5, 6, 7, 8], purpose: "Orientation values (TIFF 6.0 Section 8)"),
        enumeration("tiff-planarconfiguration", tag: 0x011C, values: [1, 2], purpose: "PlanarConfiguration values (TIFF 6.0 Section 8)"),
        enumeration("tiff-grayresponseunit", tag: 0x0122, values: [1, 2, 3, 4, 5], purpose: "GrayResponseUnit values (TIFF 6.0 Section 8)"),
        enumeration("tiff-t4options", tag: 0x0124, type: .long, values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
                    purpose: "T4Options flag combinations, including an undefined bit (TIFF 6.0 Section 11)"),
        enumeration("tiff-t6options", tag: 0x0125, type: .long, values: [0, 2], purpose: "T6Options flags (TIFF 6.0 Section 11)"),
        enumeration("tiff-resolutionunit", tag: 0x0128, values: [1, 2, 3], purpose: "ResolutionUnit values (TIFF 6.0 Section 8)"),
        enumeration("tiff-predictor", tag: 0x013D, values: [1, 2], purpose: "Predictor values (TIFF 6.0 Section 14)"),
        enumeration("tiff-inkset", tag: 0x014C, values: [1, 2], purpose: "InkSet values (TIFF 6.0 Section 16)"),
        enumeration("tiff-extrasamples", tag: 0x0152, values: [0, 1, 2], purpose: "ExtraSamples values (TIFF 6.0 Section 8)"),
        enumeration("tiff-sampleformat", tag: 0x0153, values: [1, 2, 3, 4], purpose: "SampleFormat values (TIFF 6.0 Section 19)"),
        enumeration("tiff-jpegproc", tag: 0x0200, values: [1, 14], purpose: "JPEGProc values (TIFF 6.0 Section 22)"),
        enumeration("tiff-ycbcrpositioning", tag: 0x0213, values: [1, 2], purpose: "YCbCrPositioning values (TIFF 6.0 Section 21)"),
        Fixture("tiff-jpeg-pointers", "JPEGInterchangeFormat and length in IFD0, three SubIFDs and IFD1", .tiff(TIFFBuilder(.little, chain: [
            TIFFBuilder.IFD([
                .subIFDs([TIFFBuilder.IFD([.long(0x0201, 30), .long(0x0202, 4)]),
                          TIFFBuilder.IFD([.long(0x0201, 40), .long(0x0202, 4)]),
                          TIFFBuilder.IFD([.long(0x0201, 50), .long(0x0202, 4)])]),
                .long(0x0201, 10), .long(0x0202, 4),
            ]),
            TIFFBuilder.IFD([.long(0x0201, 20), .long(0x0202, 4)]),
        ]))),
        Fixture("tiff-ycbcrsubsampling", "YCbCrSubSampling combinations (TIFF 6.0 Section 21)", .tiff(TIFFBuilder(.little, chain:
            [[1, 1], [2, 1], [2, 2], [4, 1], [4, 2]].map { TIFFBuilder.IFD([.shorts(0x0212, $0)]) }))),
    ]
}
