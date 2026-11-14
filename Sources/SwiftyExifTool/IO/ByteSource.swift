import Foundation

/// Errors raised by byte sources and the binary reader.
enum ByteSourceError: Error, Equatable {
    /// The requested range lies (partly) outside the source.
    case outOfBounds(offset: Int, count: Int)
    /// The underlying file could not be read.
    case io(String)
}

/// Random access to the bytes of a file or buffer.
///
/// Implementations are used within a single read call and are not shared
/// between tasks.
protocol ByteSource: AnyObject {
    /// Total size of the source in bytes.
    var size: Int { get }

    /// Returns exactly `count` bytes starting at `offset`.
    ///
    /// Throws ``ByteSourceError/outOfBounds(offset:count:)`` when the range
    /// does not lie entirely within the source.
    func read(offset: Int, count: Int) throws(ByteSourceError) -> Data
}

extension ByteSource {
    /// Whether `count` bytes starting at `offset` lie within the source.
    func contains(offset: Int, count: Int) -> Bool {
        guard offset >= 0, count >= 0 else { return false }
        let (end, overflow) = offset.addingReportingOverflow(count)
        return !overflow && end <= size
    }
}

/// A byte source backed by an in-memory buffer.
final class DataByteSource: ByteSource {
    private let data: Data

    init(_ data: Data) {
        // Rebase so that indices start at 0 regardless of the slice.
        self.data = Data(data)
    }

    var size: Int { data.count }

    func read(offset: Int, count: Int) throws(ByteSourceError) -> Data {
        guard contains(offset: offset, count: count) else {
            throw .outOfBounds(offset: offset, count: count)
        }
        return data.subdata(in: offset ..< offset + count)
    }
}

/// A read-only byte source backed by a file handle.
///
/// Reads go through a small cache of aligned pages so that the many tiny
/// reads of directory parsing do not each cost a system call. The file is
/// closed by ``close()`` or when the source is deallocated.
final class FileByteSource: ByteSource {
    static let pageSize = 64 * 1024
    static let maxCachedPages = 16

    let size: Int
    private var handle: FileHandle?
    private var pages: [Int: Data] = [:]
    private var pageOrder: [Int] = []
    /// Number of bytes actually read from the file, including cache fills.
    private(set) var bytesReadFromFile = 0

    /// Opens `url` for reading.
    init(url: URL) throws(ByteSourceError) {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            let end = try handle.seekToEnd()
            guard end <= UInt64(Int.max) else {
                try? handle.close()
                throw ByteSourceError.io("file too large")
            }
            self.handle = handle
            self.size = Int(end)
        } catch let error as ByteSourceError {
            throw error
        } catch {
            throw .io(String(describing: error))
        }
    }

    deinit {
        try? handle?.close()
    }

    /// Closes the underlying file. Further reads fail.
    func close() {
        try? handle?.close()
        handle = nil
        pages.removeAll()
        pageOrder.removeAll()
    }

    func read(offset: Int, count: Int) throws(ByteSourceError) -> Data {
        guard contains(offset: offset, count: count) else {
            throw .outOfBounds(offset: offset, count: count)
        }
        if count == 0 { return Data() }

        let pageSize = Self.pageSize
        let firstPage = offset / pageSize
        let lastPage = (offset + count - 1) / pageSize

        // Large reads bypass the cache.
        if lastPage - firstPage >= Self.maxCachedPages {
            return try readFromFile(offset: offset, count: count)
        }

        var result = Data(capacity: count)
        for pageIndex in firstPage ... lastPage {
            let page = try self.page(pageIndex)
            let pageStart = pageIndex * pageSize
            let from = max(offset, pageStart) - pageStart
            let to = min(offset + count, pageStart + page.count) - pageStart
            result.append(page.subdata(in: from ..< to))
        }
        return result
    }

    private func page(_ index: Int) throws(ByteSourceError) -> Data {
        if let cached = pages[index] { return cached }
        let start = index * Self.pageSize
        let length = min(Self.pageSize, size - start)
        let data = try readFromFile(offset: start, count: length)
        pages[index] = data
        pageOrder.append(index)
        if pageOrder.count > Self.maxCachedPages {
            pages.removeValue(forKey: pageOrder.removeFirst())
        }
        return data
    }

    private func readFromFile(offset: Int, count: Int) throws(ByteSourceError) -> Data {
        guard let handle else { throw .io("file is closed") }
        do {
            try handle.seek(toOffset: UInt64(offset))
            let data = try handle.read(upToCount: count) ?? Data()
            guard data.count == count else {
                throw ByteSourceError.io("short read at offset \(offset)")
            }
            bytesReadFromFile += data.count
            return data
        } catch let error as ByteSourceError {
            throw error
        } catch {
            throw .io(String(describing: error))
        }
    }
}

/// Wraps a byte source and counts the bytes it delivers. Used by tests to
/// verify that reading is bounded by the metadata, not the file size.
final class CountingByteSource: ByteSource {
    let base: any ByteSource
    private(set) var bytesRead = 0
    private(set) var readCount = 0

    init(_ base: any ByteSource) {
        self.base = base
    }

    var size: Int { base.size }

    func read(offset: Int, count: Int) throws(ByteSourceError) -> Data {
        let data = try base.read(offset: offset, count: count)
        bytesRead += data.count
        readCount += 1
        return data
    }
}
