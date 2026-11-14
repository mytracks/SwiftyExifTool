import Foundation
import FixtureKit

/// Access to the committed fixture and snapshot files bundled with the tests.
enum FixtureFiles {
    static var resourceRoot: URL {
        guard let url = Bundle.module.resourceURL else { fatalError("test bundle has no resources") }
        return url
    }

    static var syntheticDirectory: URL {
        resourceRoot.appendingPathComponent("Fixtures/synthetic")
    }

    static var snapshotDirectory: URL {
        resourceRoot.appendingPathComponent("Snapshots")
    }

    static func fixture(_ id: String) -> Fixture {
        guard let fixture = FixtureCatalogue.fixture(id) else { fatalError("unknown fixture \(id)") }
        return fixture
    }

    static func url(_ id: String) -> URL {
        syntheticDirectory.appendingPathComponent(fixture(id).fileName)
    }

    static func data(_ id: String) throws -> Data {
        try Data(contentsOf: url(id))
    }
}
