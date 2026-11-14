import Foundation
import Testing
import FixtureKit
@testable import SwiftyExifTool

/// Bounded reading (metadata-reading-api spec).
@Suite struct BoundedReadingTests {
    @Test func largeFileWithSmallMetadata() throws {
        let header = TIFFBuilder(.little, chain: [.init([
            .short(0x0100, 640), .short(0x0101, 480), .ascii(0x010F, "TestCam"),
            .long(0x0111, 4096), .long(0x0117, 200 * 1024 * 1024 - 4096),
        ])]).build().data
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("large-\(UUID().uuidString).tif")
        defer { try? FileManager.default.removeItem(at: url) }
        try header.write(to: url)
        // Extend to 200 MB without writing the data (sparse on APFS).
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 200 * 1024 * 1024)
        try handle.close()

        let source = try FileByteSource(url: url)
        defer { source.close() }
        let metadata = try MetadataReader.read(source: source, limits: .default) { _ in .unknownFormat }
        #expect(metadata.tag(.ifd0, "Make")?.value == .string("TestCam"))
        #expect(source.size == 200 * 1024 * 1024)
        #expect(source.bytesReadFromFile < 1024 * 1024)
    }
}

/// Concurrent reads (metadata-reading-api spec, "Concurrency"). Run with
/// `swift test --sanitize=thread --filter ConcurrencyTests`.
@Suite struct ConcurrencyTests {
    @Test func concurrentReads() async throws {
        let ids = Array(FixtureCatalogue.all.filter(\.isTIFF).map(\.id).prefix(50))
        let urls = ids.map(FixtureFiles.url)
        let sequential = try urls.map { try MetadataReader.read(contentsOf: $0) }
        let concurrent = try await withThrowingTaskGroup(of: (Int, Metadata).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask { (index, try MetadataReader.read(contentsOf: url)) }
            }
            var results = [Metadata?](repeating: nil, count: urls.count)
            for try await (index, metadata) in group { results[index] = metadata }
            return results.compactMap { $0 }
        }
        #expect(urls.count >= 40)
        #expect(concurrent == sequential)
    }
}
