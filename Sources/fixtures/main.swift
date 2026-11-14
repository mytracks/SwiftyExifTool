// Development tool: generates synthetic fixtures, records exiftool snapshots
// and runs the conformance tooling (openspec/specs/exiftool-conformance).
//
//   swift run fixtures generate          writes all catalogued fixtures
//   swift run fixtures snapshot          records exiftool output for every TIFF fixture
//   swift run fixtures json <file> [-n]  prints a reading result like exiftool -j -a -G1 -u [-n]
//   swift run fixtures corpus fetch      downloads the sample corpus listed in Corpus/manifest.json
//   swift run fixtures corpus snapshot   records exiftool output for the corpus (personal fields hashed)
//   swift run fixtures corpus check      reports, per corpus file and group, how far we are from exiftool
//   swift run fixtures corpus baseline   re-records the committed baseline of per-key status
//
// `corpus` subcommands accept `--manifest <path>` to use another manifest.
//
// Run from the package root. Only functional on macOS, where Process exists.
#if os(macOS)
import ConformanceKit
import FixtureKit
import Foundation
import SwiftyExifTool

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
    case "json":
        try printJSON(Array(CommandLine.arguments.dropFirst(2)))
    case "corpus":
        try await runCorpus(Array(CommandLine.arguments.dropFirst(2)))
    default:
        fail("usage: fixtures generate | snapshot | json <file> [-n] | corpus fetch | snapshot | check | baseline")
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
/// `corpus <subcommand> [--manifest <path>]`.
func runCorpus(_ arguments: [String]) async throws {
    var manifestPath: String?
    if let index = arguments.firstIndex(of: "--manifest"), index + 1 < arguments.count {
        manifestPath = arguments[index + 1]
    }
    let tool = try CorpusTool(packageRoot: root, manifestPath: manifestPath)
    switch arguments.first {
    case "fetch": try await tool.fetch()
    case "snapshot": try tool.snapshot()
    case "check": try tool.check()
    case "baseline": try tool.baseline()
    default: fail("usage: fixtures corpus fetch | snapshot | check | baseline [--manifest <path>]")
    }
}

/// `json <file> [-n]`: the reading result as exiftool-shaped JSON.
func printJSON(_ arguments: [String]) throws {
    let numeric = arguments.contains("-n")
    guard let path = arguments.first(where: { $0 != "-n" }) else { fail("usage: fixtures json <file> [-n]") }
    let url = URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    let metadata: Metadata
    do {
        metadata = try MetadataReader.read(contentsOf: url)
    } catch {
        fail("\(path): \(error)")
    }
    print(ExiftoolOutput.json(ExiftoolOutput.entries(metadata, numeric: numeric)), terminator: "")
}
#else
print("fixtures: this tool only runs on macOS")
#endif
