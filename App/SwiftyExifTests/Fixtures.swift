import Foundation
import SwiftyExifTool
@testable import SwiftyExif

private final class BundleToken {}

/// The library's committed fixtures, bundled as the folder `synthetic`.
enum Fixtures {
    static func url(_ name: String) -> URL {
        let bundle = Bundle(for: BundleToken.self)
        guard let root = bundle.resourceURL?.appendingPathComponent("synthetic") else { fatalError("no resources") }
        let tif = root.appendingPathComponent("\(name).tif")
        return FileManager.default.fileExists(atPath: tif.path) ? tif : root.appendingPathComponent("\(name).bin")
    }

    static func file(_ name: String) throws -> InspectedFile {
        let url = url(name)
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        return InspectedFile(url: url, fileSize: size, metadata: try MetadataReader.read(contentsOf: url))
    }
}
