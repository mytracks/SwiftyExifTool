import Foundation
import Testing
import FixtureKit

/// The committed fixture files must be exactly what the catalogue builds.
/// Regenerate them with `swift run fixtures generate` after catalogue changes.
@Suite struct FixtureDriftTests {
    @Test(arguments: FixtureCatalogue.all.map(\.id))
    func committedFixtureMatchesCatalogue(id: String) throws {
        let committed = try FixtureFiles.data(id)
        #expect(committed == FixtureFiles.fixture(id).build(),
                "\(id) differs from the catalogue; run `swift run fixtures generate`")
    }

    @Test func noStaleFixtureFiles() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: FixtureFiles.syntheticDirectory.path)
            .filter { !$0.hasPrefix(".") }
        #expect(Set(names) == Set(FixtureCatalogue.all.map(\.fileName)))
    }
}
