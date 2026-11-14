import Foundation
import ConformanceKit

// Snapshots and deviations bundled with the tests (ConformanceKit holds the
// comparison itself; see the exiftool-conformance spec).

extension Snapshot {
    /// Loads a synthetic fixture's snapshot from the test bundle.
    static func load(_ fixture: String) throws -> Snapshot {
        try load(fixture, in: FixtureFiles.snapshotDirectory)
    }
}

extension Deviations {
    /// Loads `deviations.json` from the test bundle.
    static func load() throws -> Deviations {
        try load(from: FixtureFiles.snapshotDirectory)
    }
}
