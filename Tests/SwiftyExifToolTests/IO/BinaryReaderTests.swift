import Foundation
import Testing
@testable import SwiftyExifTool

@Suite struct BinaryReaderTests {
    let bytes = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0xFF])

    @Test func bigEndianIntegers() throws {
        let reader = BinaryReader(source: DataByteSource(bytes), byteOrder: .bigEndian)
        #expect(try reader.uint8(at: 0) == 0x01)
        #expect(try reader.uint16(at: 0) == 0x0102)
        #expect(try reader.uint32(at: 0) == 0x0102_0304)
        #expect(try reader.uint64(at: 0) == 0x0102_0304_0506_0708)
        #expect(try reader.int8(at: 8) == -1)
        #expect(try reader.int16(at: 7) == 0x08FF)
    }

    @Test func littleEndianIntegers() throws {
        let reader = BinaryReader(source: DataByteSource(bytes), byteOrder: .littleEndian)
        #expect(try reader.uint16(at: 0) == 0x0201)
        #expect(try reader.uint32(at: 0) == 0x0403_0201)
        #expect(try reader.uint64(at: 0) == 0x0807_0605_0403_0201)
        #expect(try reader.int16(at: 7) == Int16(bitPattern: 0xFF08))
        #expect(try reader.int32(at: 5) == Int32(bitPattern: 0xFF08_0706))
    }

    @Test func floats() throws {
        var be = Data()
        withUnsafeBytes(of: Float(1.5).bitPattern.bigEndian) { be.append(contentsOf: $0) }
        withUnsafeBytes(of: Double(-2.25).bitPattern.bigEndian) { be.append(contentsOf: $0) }
        let reader = BinaryReader(source: DataByteSource(be), byteOrder: .bigEndian)
        #expect(try reader.float32(at: 0) == 1.5)
        #expect(try reader.float64(at: 4) == -2.25)

        var le = Data()
        withUnsafeBytes(of: Float(1.5).bitPattern.littleEndian) { le.append(contentsOf: $0) }
        #expect(try BinaryReader(source: DataByteSource(le), byteOrder: .littleEndian).float32(at: 0) == 1.5)
    }

    @Test func outOfBoundsAndOverflow() {
        let reader = BinaryReader(source: DataByteSource(bytes))
        #expect(throws: ByteSourceError.self) { try reader.uint32(at: 6) }
        #expect(throws: ByteSourceError.self) { try reader.uint16(at: Int.max) }
        #expect(throws: ByteSourceError.self) { try reader.uint16(at: Int.max - 1) }
        #expect(throws: ByteSourceError.self) { try reader.uint8(at: -1) }
        #expect(!reader.contains(offset: Int.max, count: 1))
    }

    @Test func zeroLengthReads() throws {
        let reader = BinaryReader(source: DataByteSource(bytes))
        #expect(try reader.bytes(at: 9, count: 0) == Data())
        #expect(reader.contains(offset: 9, count: 0))
        #expect(!reader.contains(offset: 10, count: 0))
    }

    @Test func absoluteOffsets() {
        let reader = BinaryReader(source: DataByteSource(bytes), baseOffset: 100)
        #expect(reader.absolute(8) == 108)
        let huge = BinaryReader(source: DataByteSource(bytes), baseOffset: Int.max - 1)
        #expect(huge.absolute(10) == nil)
    }
}
