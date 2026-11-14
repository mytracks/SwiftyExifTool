import Foundation
import Testing
@testable import SwiftyExifTool

@Suite struct ByteSourceTests {
    static func pattern(_ count: Int) -> Data {
        Data((0 ..< count).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
    }

    static func temporaryFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ByteSourceTests-\(UUID().uuidString).bin")
        try data.write(to: url)
        return url
    }

    @Test func dataSourceReadsRanges() throws {
        let data = Self.pattern(100)
        let source = DataByteSource(data)
        #expect(source.size == 100)
        #expect(try source.read(offset: 0, count: 4) == data.prefix(4))
        #expect(try source.read(offset: 50, count: 10) == data.subdata(in: 50 ..< 60))
        #expect(try source.read(offset: 96, count: 4) == data.suffix(4))
        #expect(try source.read(offset: 100, count: 0) == Data())
    }

    @Test func dataSourceRebasesSlices() throws {
        let data = Self.pattern(100)
        let source = DataByteSource(data[10 ..< 20])
        #expect(source.size == 10)
        #expect(try source.read(offset: 0, count: 2) == data.subdata(in: 10 ..< 12))
    }

    @Test func dataSourceRejectsOutOfRange() {
        let source = DataByteSource(Self.pattern(10))
        #expect(throws: ByteSourceError.outOfBounds(offset: 8, count: 4)) {
            try source.read(offset: 8, count: 4)
        }
        #expect(throws: ByteSourceError.outOfBounds(offset: -1, count: 1)) {
            try source.read(offset: -1, count: 1)
        }
        #expect(throws: ByteSourceError.outOfBounds(offset: Int.max, count: 2)) {
            try source.read(offset: Int.max, count: 2)
        }
    }

    @Test func fileSourceReadsStartMiddleEndAndAcrossPages() throws {
        let size = FileByteSource.pageSize * 3 + 123
        let data = Self.pattern(size)
        let url = try Self.temporaryFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = try FileByteSource(url: url)
        #expect(source.size == size)
        #expect(try source.read(offset: 0, count: 8) == data.prefix(8))
        let middle = FileByteSource.pageSize - 3
        #expect(try source.read(offset: middle, count: 10) == data.subdata(in: middle ..< middle + 10))
        #expect(try source.read(offset: size - 5, count: 5) == data.suffix(5))
        // A read spanning all pages bypasses the cache but returns the same bytes.
        #expect(try source.read(offset: 1, count: size - 2) == data.subdata(in: 1 ..< size - 1))
    }

    @Test func fileSourceRejectsOutOfRange() throws {
        let url = try Self.temporaryFile(Self.pattern(10))
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try FileByteSource(url: url)
        #expect(throws: ByteSourceError.outOfBounds(offset: 5, count: 6)) {
            try source.read(offset: 5, count: 6)
        }
    }

    @Test func fileSourceFailsAfterClose() throws {
        let url = try Self.temporaryFile(Self.pattern(10))
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try FileByteSource(url: url)
        source.close()
        #expect(throws: ByteSourceError.self) { try source.read(offset: 0, count: 1) }
    }

    @Test func missingFileFails() {
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
        #expect(throws: ByteSourceError.self) { try FileByteSource(url: url) }
    }

    @Test func fileSourceCachesPages() throws {
        let url = try Self.temporaryFile(Self.pattern(1000))
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try FileByteSource(url: url)
        for offset in stride(from: 0, to: 900, by: 12) {
            _ = try source.read(offset: offset, count: 12)
        }
        #expect(source.bytesReadFromFile == 1000)
    }
}

@Suite struct CountingByteSourceTests {
    @Test func countsDeliveredBytes() throws {
        let source = CountingByteSource(DataByteSource(Data(count: 100)))
        _ = try source.read(offset: 0, count: 8)
        _ = try source.read(offset: 10, count: 2)
        _ = try? source.read(offset: 99, count: 2)
        #expect(source.bytesRead == 10)
        #expect(source.readCount == 2)
    }
}
