// Development tool: generates synthetic fixtures and records exiftool snapshots.
//
//   swift run fixtures generate   writes all catalogued fixtures
//   swift run fixtures snapshot   records exiftool output for every TIFF fixture
//
// Run from the package root. Only functional on macOS, where Process exists.
#if os(macOS)
import FixtureKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("fixtures: \(message)\n".utf8))
    exit(1)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) else {
    fail("run this tool from the package root")
}
let fixtureDirectory = root.appendingPathComponent(FixtureCatalogue.relativeDirectory)

do {
    switch CommandLine.arguments.dropFirst().first {
    case "generate":
        try generate(into: fixtureDirectory)
    case "snapshot":
        try Snapshotter(fixtureDirectory: fixtureDirectory,
                        snapshotDirectory: root.appendingPathComponent(Snapshotter.relativeDirectory)).run()
    default:
        fail("usage: fixtures generate | snapshot")
    }
} catch {
    fail(String(describing: error))
}

func generate(into directory: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    // Remove stale fixtures so the directory mirrors the catalogue.
    let expected = Set(FixtureCatalogue.all.map(\.fileName))
    for name in try fm.contentsOfDirectory(atPath: directory.path)
    where !name.hasPrefix(".") && !expected.contains(name) {
        try fm.removeItem(at: directory.appendingPathComponent(name))
        print("removed \(name)")
    }
    for fixture in FixtureCatalogue.all {
        try fixture.build().write(to: directory.appendingPathComponent(fixture.fileName))
    }
    print("wrote \(FixtureCatalogue.all.count) fixtures to \(FixtureCatalogue.relativeDirectory)")
}
#else
print("fixtures: this tool only runs on macOS")
#endif
