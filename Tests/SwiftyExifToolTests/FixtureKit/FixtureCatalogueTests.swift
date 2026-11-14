import Testing
import FixtureKit

@Suite struct FixtureCatalogueTests {
    @Test func idsAreUniqueAndPurposesAreOneLine() {
        let ids = FixtureCatalogue.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for fixture in FixtureCatalogue.all {
            #expect(!fixture.purpose.isEmpty, "\(fixture.id) has no purpose")
            #expect(!fixture.purpose.contains("\n"), "\(fixture.id) purpose spans lines")
            #expect(fixture.id.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }, "\(fixture.id)")
        }
    }
}
