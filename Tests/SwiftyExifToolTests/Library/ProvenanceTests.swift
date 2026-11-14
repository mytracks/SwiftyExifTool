import Foundation
import Testing
import FixtureKit
@testable import SwiftyExifTool

/// Every tag definition has a recorded source and is confirmed by at least
/// one exiftool snapshot (exif-tags spec, "Standard tag coverage"; design D6).
@Suite struct ProvenanceTests {
    /// Problems with the provenance of `definitions`, given the tag names seen
    /// in snapshots (`table` → names) and the names exiftool only shows in `-v2`.
    static func problems(_ definitions: [TagDefinition], observed: Set<String>, verboseOnly: Set<String>,
                         deviations: Deviations = Deviations(items: [])) -> [String] {
        var problems: [String] = []
        for definition in definitions {
            let label = "\(definition.name) (0x\(String(format: "%04X", definition.id)))"
            switch definition.source {
            case .specification(_, let section):
                if section.trimmingCharacters(in: .whitespaces).isEmpty { problems.append("\(label): empty section") }
            case .observation(let fixture):
                if FixtureCatalogue.fixture(fixture) == nil { problems.append("\(label): unknown fixture \(fixture)") }
            }
            if EmbeddedBlockTags.hiddenByExiftool.contains(definition.id) && definition.table == .main {
                if !verboseOnly.contains(definition.name) { problems.append("\(label): not in any -v2 snapshot") }
                continue
            }
            // Tags exiftool does not know are documented deviations instead.
            for name in definition.allNames where !observed.contains("\(definition.table):\(name)")
                && !deviations.isAccepted(fixture: "*", key: "Any:\(name)") {
                problems.append("\(label): name \(name) not observed in any snapshot")
            }
        }
        return problems
    }

    static func observedNames() throws -> (observed: Set<String>, verbose: Set<String>) {
        var observed: Set<String> = []
        var verbose: Set<String> = []
        for fixture in FixtureCatalogue.all where fixture.isTIFF {
            let snapshot = try Snapshot.load(fixture.id)
            for entry in snapshot.rawTags {
                observed.insert("\(entry.group == "GPS" ? "gps" : "main"):\(entry.name)")
            }
            for line in snapshot.verbose {
                // "  | 1)  ApplicationNotes (SubDirectory) -->"
                if let range = line.range(of: #"\d+\)\s+(\S+)"#, options: .regularExpression) {
                    let name = line[range].split(separator: " ", omittingEmptySubsequences: true).last.map(String.init)
                    if let name { verbose.insert(name) }
                }
            }
        }
        return (observed, verbose)
    }

    @Test func everyDefinitionIsSourcedAndObserved() throws {
        let (observed, verbose) = try Self.observedNames()
        let problems = Self.problems(TagRegistry.definitions, observed: observed, verboseOnly: verbose,
                                     deviations: try Deviations.load())
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test func missingSourceOrObservationIsDetected() throws {
        let (observed, verbose) = try Self.observedNames()
        let unsourced = TagDefinition(0x0100, "ImageWidth", source: .specification(.tiff6, section: " "))
        let unobserved = TagDefinition(0x0100, "ImageBreadth", source: .tiff6("Section 8"))
        let badFixture = TagDefinition(0x0100, "ImageWidth", source: .observation(fixture: "no-such-fixture"))
        #expect(Self.problems([unsourced], observed: observed, verboseOnly: verbose).count == 1)
        #expect(Self.problems([unobserved], observed: observed, verboseOnly: verbose).count == 1)
        #expect(Self.problems([badFixture], observed: observed, verboseOnly: verbose).count == 1)
    }

    @Test func noDuplicateDefinitions() {
        var seen: Set<String> = []
        for definition in TagRegistry.definitions {
            #expect(seen.insert("\(definition.table):\(definition.id)").inserted, "duplicate 0x\(String(definition.id, radix: 16))")
        }
    }
}
