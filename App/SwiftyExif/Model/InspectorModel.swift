import Foundation
import Observation
import SwiftyExifTool

/// The state of the window: which file is shown and how far reading got.
@MainActor
@Observable
final class InspectorModel {
    enum State: Sendable {
        case empty
        case loading(URL)
        case loaded(InspectedFile)
        case failed(URL, ReadError)
    }

    /// Reads a file; injectable for tests.
    typealias Reader = @Sendable (URL) throws(ReadError) -> Metadata

    private(set) var state: State = .empty
    var query = TagQuery()

    private let reader: Reader
    private let pasteboard: any Pasteboard
    /// Incremented per open; results of older reads are discarded.
    private var generation = 0

    init(reader: @escaping Reader = { url throws(ReadError) in try MetadataReader.read(contentsOf: url) },
         pasteboard: any Pasteboard = SystemPasteboard()) {
        self.reader = reader
        self.pasteboard = pasteboard
    }

    var file: InspectedFile? {
        if case .loaded(let file) = state { file } else { nil }
    }

    var isLoading: Bool {
        if case .loading = state { true } else { false }
    }

    /// Reads `url` off the main actor and shows the result, unless another
    /// file was opened in the meantime. `displayName` overrides the shown name
    /// (dropped files arrive as temporary copies).
    @discardableResult
    func open(_ url: URL, displayName: String? = nil) -> Task<Void, Never> {
        generation += 1
        let current = generation
        state = .loading(url)
        query = TagQuery()
        let reader = self.reader
        return Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<InspectedFile, ReadError> in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
                do throws(ReadError) {
                    let metadata = try reader(url)
                    return .success(InspectedFile(url: url, displayName: displayName, fileSize: size, metadata: metadata))
                } catch {
                    return .failure(error)
                }
            }.value
            guard current == generation else { return }
            switch result {
            case .success(let file): state = .loaded(file)
            case .failure(let error): state = .failed(url, error)
            }
        }
    }

    /// The sections shown for the current query.
    var sections: [GroupSection] {
        guard let file else { return [] }
        return query.sections(for: file.rows)
    }

    func copyValue(_ row: TagRow) { pasteboard.setString(CopyText.value(row)) }
    func copyDisplay(_ row: TagRow) { pasteboard.setString(CopyText.display(row)) }
    func copyRows(_ rows: [TagRow]) { pasteboard.setString(CopyText.rows(rows)) }
}

extension ReadError {
    /// A message for the error view.
    var userMessage: String {
        switch self {
        case .unsupportedFormat(let format): "\(format) is not supported."
        case .unknownFormat: "The file format is unknown."
        case .fileAccess(_, let reason): "The file could not be read: \(reason)"
        @unknown default: description
        }
    }
}
