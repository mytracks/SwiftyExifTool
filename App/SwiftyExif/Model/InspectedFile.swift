import Foundation
import SwiftyExifTool

/// A file that was read successfully, with precomputed rows.
struct InspectedFile: Sendable {
    let url: URL
    /// The name to show; differs from the URL for dropped copies.
    let displayName: String
    let fileSize: Int?
    let metadata: Metadata
    let rows: [TagRow]

    init(url: URL, displayName: String? = nil, fileSize: Int?, metadata: Metadata) {
        self.url = url
        self.displayName = displayName ?? url.lastPathComponent
        self.fileSize = fileSize
        self.metadata = metadata
        rows = metadata.tags.enumerated().map { TagRow(id: $0.offset, tag: $0.element) }
    }

    var fileTypeText: String { metadata.fileType.name }

    var byteOrderText: String {
        switch metadata.byteOrder {
        case .littleEndian: "Little-endian (II)"
        case .bigEndian: "Big-endian (MM)"
        case nil: "–"
        }
    }

    var fileSizeText: String {
        guard let fileSize else { return "–" }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file) + " (\(fileSize) bytes)"
    }

    var tagCount: Int { metadata.tags.count }
    var directoryCount: Int { metadata.directories.count }
    var warningCount: Int { metadata.warnings.count }

    /// Groups in the order they first occur, with their tag counts.
    var groups: [(group: TagGroup, count: Int)] {
        var order: [TagGroup] = []
        var counts: [TagGroup: Int] = [:]
        for row in rows {
            if counts[row.group] == nil { order.append(row.group) }
            counts[row.group, default: 0] += 1
        }
        return order.map { ($0, counts[$0] ?? 0) }
    }
}
