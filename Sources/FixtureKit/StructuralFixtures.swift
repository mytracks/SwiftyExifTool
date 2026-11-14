import Foundation

typealias E = TIFFBuilder.Entry
typealias D = TIFFBuilder.IFD

extension FixtureCatalogue {
    static func basic(_ order: TIFFBuilder.ByteOrder) -> TIFFBuilder {
        TIFFBuilder(order, chain: [
            D([
                .short(0x0100, 640),
                .short(0x0101, 480),
                .ascii(0x010F, "TestCam"),
                .short(0x0112, 6),
                .rational(0x011A, 300, 1),
                .short(0x0128, 2),
                .exif(D([
                    .rational(0x829A, 1, 250),
                    .short(0x8827, 200),
                    .ascii(0x9003, "2026:11:14 10:00:00"),
                    .short(0x9209, 16),
                ])),
                .gps(D([
                    .byte(0x0000, [2, 3, 0, 0]),
                    .ascii(0x0001, "N"),
                ])),
            ]),
            D([.short(0x0100, 160)]),
        ])
    }

    /// Tag IDs used by structural fixtures where only the structure matters.
    /// They lie in the private range above 0xF000 and are expected to be unknown.
    static let privateTags: [UInt16] = Array(0xF001 ... 0xF020)

    static func fieldTypes() -> TIFFBuilder {
        let t = privateTags
        typealias R = TIFFBuilder.Rational
        typealias S = TIFFBuilder.SRational
        return TIFFBuilder(.little, chain: [D([
            E(t[0], .byte, .bytes([7])),
            E(t[1], .byte, .bytes([1, 2, 3])),
            E(t[2], .ascii, .bytes(Array("A".utf8) + [0])),
            E(t[3], .ascii, .bytes(Array("ABCDEFG".utf8) + [0])),
            E(t[4], .short, .shorts([65535])),
            E(t[5], .short, .shorts([1, 2, 3])),
            E(t[6], .long, .longs([4_000_000_000])),
            E(t[7], .long, .longs([1, 2, 3])),
            E(t[8], .rational, .rationals([R(1, 3)])),
            E(t[9], .rational, .rationals([R(1, 2), R(3, 4), R(5, 6)])),
            E(t[10], .sbyte, .bytes([UInt8(bitPattern: -5)])),
            E(t[11], .sbyte, .bytes([UInt8(bitPattern: -1), 0, 1])),
            E(t[12], .undefined, .bytes([0xAB])),
            E(t[13], .undefined, .bytes([0x01, 0x02, 0x03])),
            E(t[14], .sshort, .sshorts([-300])),
            E(t[15], .sshort, .sshorts([-1, 0, 1])),
            E(t[16], .slong, .slongs([-70000])),
            E(t[17], .slong, .slongs([-1, 0, 1])),
            E(t[18], .srational, .srationals([S(-1, 3)])),
            E(t[19], .srational, .srationals([S(-1, 2), S(3, -4), S(5, 6)])),
            E(t[20], .float, .floats([1.5])),
            E(t[21], .float, .floats([-0.25, 0, 2])),
            E(t[22], .double, .doubles([3.25])),
            E(t[23], .double, .doubles([-1e10, 0, 0.125])),
            E(t[24], .utf8, .bytes(Array("Zürich".utf8) + [0])),
            // Number formatting edge cases.
            E(t[25], .float, .floats([0.1])),
            E(t[26], .double, .doubles([0.1])),
            E(t[27], .rational, .rationals([R(1, 0)])),
            E(t[28], .rational, .rationals([R(0, 0)])),
            E(t[29], .srational, .srationals([S(-1, 0)])),
            E(t[30], .rational, .rationals([R(1, 30_000_000)])),
            E(t[31], .double, .doubles([123456789012.5])),
        ])])
    }

    static func tooManyIFDs() -> TIFFBuilder {
        TIFFBuilder(.little, chain: (0 ..< 300).map { D([.short(0x0100, UInt16($0))]) })
    }

    static func valueBeyondEOF() -> TIFFBuilder {
        // 8 header + 2 + 3 * 12 + 4 = 50 bytes; Make claims 20 bytes at offset 46.
        TIFFBuilder(.little, chain: [D([
            .short(0x0100, 10),
            E(tag: 0x010F, type: 2, count: 20, payload: .valueField(46)),
            .ascii(0x0110, "abc"),
        ])])
    }

    static var truncatedIFD0: TIFFBuilder {
        var builder = TIFFBuilder(.little, chain: [D([
            .short(0x0100, 10), .short(0x0101, 20), .short(0x0112, 1),
        ])])
        builder.truncateTo = 8 + 2 + 12
        return builder
    }

    static var ifd0BeyondEOF: TIFFBuilder {
        var builder = TIFFBuilder(.little, chain: [D([.short(0x0100, 10)])])
        builder.ifd0OffsetOverride = 99999
        return builder
    }

    static var selfLinkedIFD0: TIFFBuilder {
        var builder = TIFFBuilder(.little, chain: [D([.short(0x0100, 10), .short(0x0112, 1)])])
        builder.linkLastIFDTo = 0
        return builder
    }

    static let structural: [Fixture] = [
        Fixture("basic-le", "Little-endian TIFF with IFD0, ExifIFD, GPS and IFD1", .tiff(basic(.little))),
        Fixture("basic-be", "Big-endian variant of basic-le", .tiff(basic(.big))),
        Fixture("field-types", "One entry per field type with counts 1 and 3, plus UTF-8", .tiff(fieldTypes())),
        Fixture("ifd-chain", "IFD0 linked to IFD1 and IFD2", .tiff(TIFFBuilder(.little, chain: [
            D([.short(0x0100, 1)]), D([.short(0x0100, 2)]), D([.short(0x0100, 3)]),
        ]))),
        Fixture("subifds", "Two SubIFDs, ExifIFD with InteropIFD, and IFD1 (traversal order)", .tiff(TIFFBuilder(.little, chain: [
            D([
                .short(0x0100, 1),
                .subIFDs([D([.short(0x0100, 2)]), D([.short(0x0100, 3)])]),
                .exif(D([.interop(D([.ascii(0x0001, "R98")]))])),
            ]),
            D([.short(0x0100, 4)]),
        ]))),
        Fixture("exif-gps-interop", "IFD0 with ExifIFD, GPS and InteropIFD sharing ID 0x0001", .tiff(TIFFBuilder(.big, chain: [
            D([
                .short(0x0100, 1),
                .exif(D([.rational(0x829A, 1, 60), .interop(D([.ascii(0x0001, "R98")]))])),
                .gps(D([.ascii(0x0001, "N")])),
            ]),
        ]))),
        Fixture("unknown-field-type", "An entry with field type 99 between two valid entries", .tiff(TIFFBuilder(.little, chain: [
            D([.short(0x0100, 10), E(tag: 0x0101, type: 99, count: 1, payload: .valueField(5)), .ascii(0x010F, "TestCam")]),
        ]))),
        Fixture("unknown-tags", "Unknown tags in IFD0, GPS and InteropIFD", .tiff(TIFFBuilder(.little, chain: [
            D([
                .short(0x0100, 10),
                .short(0xC0DE, 7),
                .exif(D([.interop(D([.short(0x0077, 9)]))])),
                .gps(D([.short(0x0077, 9)])),
            ]),
        ]))),
        Fixture("exif-in-ifd0", "ExposureTime stored in IFD0 instead of ExifIFD", .tiff(TIFFBuilder(.little, chain: [
            D([.short(0x0100, 10), .rational(0x829A, 1, 125)]),
        ]))),
        Fixture("orientation-unknown", "Orientation with a value its definition does not list", .tiff(TIFFBuilder(.little, chain: [
            D([.short(0x0100, 10), .short(0x0112, 99)]),
        ]))),
        Fixture("bad-exif-pointer", "ExifIFD pointer beyond the end of the file", .tiff(TIFFBuilder(.little, chain: [
            D([.short(0x0100, 10), E(tag: 0x8769, type: 4, count: 1, payload: .valueField(99999))]),
        ]))),
        Fixture("truncated-ifd0", "IFD0 declares 3 entries but the file ends after 12 bytes of its table", .tiff(truncatedIFD0)),
        Fixture("ifd0-beyond-eof", "Header points IFD0 beyond the end of the file", .tiff(ifd0BeyondEOF)),
        Fixture("self-linked-ifd0", "IFD0's next-IFD offset points to IFD0", .tiff(selfLinkedIFD0)),
        Fixture("too-many-ifds", "A chain of 300 IFDs, above the directory limit", .tiff(tooManyIFDs())),
        Fixture("large-undefined", "A 1 MiB UNDEFINED value", .tiff(TIFFBuilder(.little, chain: [
            D([.short(0x0100, 10), E(privateTags[0], .undefined, .bytes([UInt8](repeating: 0x5A, count: 1 << 20)))]),
        ]))),
        Fixture("value-beyond-eof", "An ASCII value extending beyond the end of the file", .tiff(valueBeyondEOF())),
        Fixture("strings", "Padded ASCII, ISO 8859-1 bytes and UTF-8 strings", .tiff(TIFFBuilder(.little, chain: [
            D([
                .asciiBytes(0x010F, Array("Cam".utf8) + [0x20, 0x20, 0, 0, 0]),
                .asciiBytes(0x013B, [0x4D, 0xFC, 0x6C, 0x6C, 0x65, 0x72, 0x00]),
                .ascii(0x0131, "Ünïcødé"),
            ]),
        ]))),
        Fixture("strings-spaces", "ASCII values consisting only of spaces, with and without NUL", .tiff(TIFFBuilder(.little, chain: [
            D([
                .asciiBytes(0x010E, [UInt8](repeating: 0x20, count: 8) + [0]),
                .asciiBytes(0x010F, [UInt8](repeating: 0x20, count: 4)),
                .asciiBytes(0x0110, [0x41, 0x20, 0x20, 0x00]),
                .asciiBytes(0x0131, [0x00, 0x00, 0x00, 0x00]),
            ]),
        ]))),
        Fixture("embedded-blocks", "XMP, MakerNote, IPTC and ICC blocks left undecoded", .tiff(TIFFBuilder(.little, chain: [
            D([
                .short(0x0100, 10),
                .byte(0x02BC, Array("<x:xmpmeta xmlns:x='adobe:ns:meta/'/>   ".utf8)),
                .undefined(0x83BB, [UInt8](repeating: 0, count: 16)),
                .exif(D([.undefined(0x927C, [UInt8](repeating: 0, count: 64))])),
                .undefined(0x8773, [UInt8](repeating: 0, count: 24)),
            ]),
        ]))),
    ]

    static let signatures: [Fixture] = [
        Fixture("sig-bigtiff", "BigTIFF header (version 43)", .raw(Data([0x49, 0x49, 0x2B, 0x00, 0x08, 0x00, 0x00, 0x00] + [UInt8](repeating: 0, count: 16)))),
        Fixture("sig-jpeg", "JPEG SOI marker followed by an APP0 marker", .raw(Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10] + Array("JFIF".utf8) + [0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0xFF, 0xD9]))),
        Fixture("sig-png", "PNG signature", .raw(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]))),
        Fixture("sig-isobmff", "ISO BMFF ftyp box with major brand abcd", .raw(Data([0, 0, 0, 0x14] + Array("ftypabcd".utf8) + [0, 0, 0, 0] + Array("abcd".utf8)))),
        Fixture("sig-text", "Plain ASCII text", .raw(Data("hello world".utf8))),
        Fixture("sig-empty", "Zero-byte file", .raw(Data())),
    ]
}
