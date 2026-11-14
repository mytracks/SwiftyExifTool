#if os(macOS)
import Foundation

/// Runs the exiftool binary for black-box observations (docs/clean-room.md).
enum Exiftool {
    static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["exiftool"] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        if process.terminationStatus == 127 {
            throw ToolError("exiftool not found on PATH; install it with `brew install exiftool`")
        }
        // exiftool exits with 1 when a file has errors but still prints output.
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw ToolError("exiftool \(arguments.joined(separator: " ")) produced no output (status \(process.terminationStatus))")
        }
        return text
    }

    static func version() throws -> String {
        try run(["-ver"]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
