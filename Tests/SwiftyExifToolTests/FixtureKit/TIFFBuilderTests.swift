import Foundation
import Testing
import FixtureKit

@Suite struct TIFFBuilderTests {
    @Test func twoEntryLittleEndianIFD() {
        let output = TIFFBuilder(.little, chain: [
            .init([.short(0x0100, 640), .ascii(0x010F, "TestCam")]),
        ]).build()

        let expected: [UInt8] = [
            0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, // header, IFD0 at 8
            0x02, 0x00, // 2 entries
            0x00, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x80, 0x02, 0x00, 0x00, // ImageWidth SHORT 640
            0x0F, 0x01, 0x02, 0x00, 0x08, 0x00, 0x00, 0x00, 0x26, 0x00, 0x00, 0x00, // Make ASCII[8] @38
            0x00, 0x00, 0x00, 0x00, // next IFD
            0x54, 0x65, 0x73, 0x74, 0x43, 0x61, 0x6D, 0x00, // "TestCam\0"
        ]
        #expect(Array(output.data) == expected)
        #expect(output.location("IFD0", 0x010F)?.valueOffset == 38)
        #expect(output.location("IFD0", 0x010F)?.entryOffset == 22)
        #expect(output.directoryOffsets["IFD0"] == 8)
    }

    @Test func bigEndianShortIsLeftJustified() {
        let output = TIFFBuilder(.big, chain: [.init([.short(0x0100, 640)])]).build()
        let expected: [UInt8] = [
            0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,
            0x00, 0x01,
            0x01, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x02, 0x80, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        ]
        #expect(Array(output.data) == expected)
    }

    @Test func chainAndSubdirectoriesAreLinked() {
        let output = TIFFBuilder(.little, chain: [
            .init([.subIFDs([.init([.short(0x0100, 2)]), .init([.short(0x0100, 3)])]),
                   .exif(.init([.interop(.init([.ascii(0x0001, "R98")]))]))]),
            .init([.short(0x0100, 4)]),
        ]).build()
        let offsets = output.directoryOffsets
        #expect(offsets.keys.sorted() == ["IFD0", "IFD0/014A[0]", "IFD0/014A[1]", "IFD0/8769", "IFD0/8769/A005", "IFD1"])
        // Directories are laid out in traversal order.
        let order = offsets.sorted { $0.value < $1.value }.map(\.key)
        #expect(order == ["IFD0", "IFD0/014A[0]", "IFD0/014A[1]", "IFD0/8769", "IFD0/8769/A005", "IFD1"])
    }

    @Test func patchesAndTruncation() {
        var builder = TIFFBuilder(.little, chain: [.init([.short(0x0100, 1)])])
        builder.patches = [(offset: 8, bytes: [0x03])]
        builder.truncateTo = 12
        let output = builder.build()
        #expect(output.data.count == 12)
        #expect(output.data[8] == 0x03)
    }
}
