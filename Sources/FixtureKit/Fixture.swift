import Foundation

/// A named synthetic test file.
public struct Fixture: Sendable {
    public enum Kind: Sendable {
        /// A TIFF-structured file; exiftool snapshots are recorded for it.
        case tiff(TIFFBuilder)
        /// Raw bytes (signature tests); no snapshot.
        case raw(Data)
    }

    /// Unique identifier, also the file name without extension.
    public let id: String
    /// One line describing what the fixture exercises.
    public let purpose: String
    public let kind: Kind

    public init(_ id: String, _ purpose: String, _ kind: Kind) {
        self.id = id
        self.purpose = purpose
        self.kind = kind
    }

    public var isTIFF: Bool { if case .tiff = kind { true } else { false } }

    public var fileName: String { "\(id).\(isTIFF ? "tif" : "bin")" }

    public func build() -> Data {
        switch kind {
        case .tiff(let builder): builder.build().data
        case .raw(let data): data
        }
    }

    /// Layout information for TIFF fixtures.
    public func layout() -> TIFFBuilder.Output? {
        if case .tiff(let builder) = kind { builder.build() } else { nil }
    }
}

public enum FixtureCatalogue {
    /// Every catalogued fixture, structural and tag fixtures.
    public static let all: [Fixture] = structural + signatures + TagFixtures.all

    public static func fixture(_ id: String) -> Fixture? {
        all.first { $0.id == id }
    }

    /// Directory of committed fixtures relative to the package root.
    public static let relativeDirectory = "Tests/SwiftyExifToolTests/Fixtures/synthetic"
}
