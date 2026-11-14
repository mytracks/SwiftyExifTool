import CryptoKit
import Foundation

/// The committed description of the sample corpus (exiftool-conformance
/// spec, "Sample corpus manifest"; design D5).
public struct CorpusManifest: Decodable, Sendable {
    public struct File: Decodable, Sendable, Hashable {
        public let id: String
        public let fileName: String
        public let url: URL
        public let licence: String
        public let sha256: String
        public let camera: String
        public let format: String
        public let source: URL
    }

    public let files: [File]

    /// The only licence accepted for corpus files.
    public static let acceptedLicence = "CC0-1.0"

    /// Path of the manifest relative to the package root.
    public static let relativePath = "Corpus/manifest.json"

    /// Decodes and checks a manifest: CC0 only, unique IDs and file names,
    /// SHA-256 as 64 lowercase hex digits.
    public init(data: Data) throws {
        struct Raw: Decodable { let files: [File] }
        let files = try JSONDecoder().decode(Raw.self, from: data).files
        for file in files {
            guard file.licence == Self.acceptedLicence else {
                throw ConformanceError("corpus manifest: \(file.id) has licence \(file.licence); only \(Self.acceptedLicence) is accepted")
            }
            guard file.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
                throw ConformanceError("corpus manifest: \(file.id) has an invalid sha256")
            }
        }
        guard Set(files.map(\.id)).count == files.count, Set(files.map(\.fileName)).count == files.count else {
            throw ConformanceError("corpus manifest: IDs and file names must be unique")
        }
        self.files = files
    }

    public static func load(from url: URL) throws -> CorpusManifest {
        try CorpusManifest(data: Data(contentsOf: url))
    }
}

/// Where the corpus lives and how its files are checked (design D5).
public enum Corpus {
    /// The environment variable that overrides the corpus directory.
    public static let environmentVariable = "SWIFTYEXIF_CORPUS"

    /// `SWIFTYEXIF_CORPUS` when set, otherwise `Corpus/` in the package root.
    public static func directory(packageRoot: URL,
                                 environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let path = environment[environmentVariable], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return packageRoot.appendingPathComponent("Corpus", isDirectory: true)
    }

    /// The package root: the nearest directory above `filePath` that
    /// contains `Package.swift` (pass `#filePath` of a source file).
    public static func packageRoot(fromSourceFile filePath: String) -> URL? {
        var directory = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        return nil
    }

    /// The lowercase hex SHA-256 of a file, read in 1 MiB chunks.
    public static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// The lowercase hex SHA-256 of a text's UTF-8 bytes.
    public static func sha256(of text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
