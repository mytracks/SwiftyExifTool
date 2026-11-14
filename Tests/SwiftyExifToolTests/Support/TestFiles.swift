import Foundation

/// Temporary files for tests; removed by `cleanup()`.
struct TemporaryFile {
    let url: URL

    init(name: String = "file.bin", data: Data) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftyExifToolTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent(name)
        try data.write(to: url)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
