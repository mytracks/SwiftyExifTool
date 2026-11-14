import Foundation
import Testing
import SwiftyExifTool

// The README's usage example, verbatim. ReadmeExampleTests checks that the
// README still contains exactly this code.
func printMetadata(of url: URL) throws {
    let metadata = try MetadataReader.read(contentsOf: url)
    for tag in metadata.tags {
        print("\(tag.group):\(tag.name) = \(tag.displayText)")
    }
    if let exposure = metadata.tag(.exifIFD, "ExposureTime") {
        print(exposure.value)        // 0.004   (as `exiftool -n`)
        print(exposure.displayText)  // 1/250   (as `exiftool`)
    }
    for warning in metadata.warnings {
        print("warning:", warning)
    }
}

@Suite struct ReadmeExampleTests {
    @Test func exampleRuns() throws {
        try printMetadata(of: FixtureFiles.url("basic-le"))
        let exposure = try MetadataReader.read(contentsOf: FixtureFiles.url("basic-le")).tag(.exifIFD, "ExposureTime")
        #expect(exposure?.value.description == "0.004")
        #expect(exposure?.displayText == "1/250")
    }

    @Test func readmeContainsTheExample() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard let readme = try? String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8),
              let source = try? String(contentsOf: testFile, encoding: .utf8)
        else { return } // Sources are not readable (e.g. on a device).
        let start = try #require(source.range(of: "func printMetadata(of url: URL) throws {"))
        let end = try #require(source.range(of: "\n}\n", range: start.upperBound ..< source.endIndex))
        let example = String(source[start.lowerBound ..< end.upperBound])
        #expect(readme.contains(example), "README usage example differs from ReadmeExampleTests.swift")
    }
}
