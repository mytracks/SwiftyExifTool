import Foundation
import Testing
import FixtureKit
@testable import SwiftyExifTool

/// Deterministic pseudo-random numbers (SplitMix64), so failures are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// No input may crash, trap or hang the reader (tiff-container spec,
/// "No traps on malformed input"). Set `SWIFTYEXIFTOOL_FUZZ_ITERATIONS` for
/// longer local runs.
@Suite struct FuzzTests {
    static let iterations = ProcessInfo.processInfo.environment["SWIFTYEXIFTOOL_FUZZ_ITERATIONS"].flatMap(Int.init) ?? 2000
    static let seed: UInt64 = 0x5EED_E417

    /// Small limits keep mutated chains fast; behaviour is the same.
    static let limits = ReadingLimits(maxDirectories: 64, maxDepth: 8, maxLoadedValueSize: 64 * 1024)

    func survive(_ data: Data, _ context: @autoclosure () -> String) {
        do {
            let metadata = try MetadataReader.read(data: data, limits: Self.limits)
            #expect(metadata.directories.count <= Self.limits.maxDirectories, "\(context())")
        } catch {
            // Errors are acceptable; crashes are not.
        }
    }

    @Test func randomBytesAfterValidHeader() {
        var rng = SplitMix64(seed: Self.seed)
        for iteration in 0 ..< Self.iterations {
            let littleEndian = Bool.random(using: &rng)
            var bytes: [UInt8] = littleEndian ? [0x49, 0x49, 0x2A, 0x00] : [0x4D, 0x4D, 0x00, 0x2A]
            // IFD0 offset: mostly small and plausible, sometimes arbitrary.
            let ifd0: UInt32 = Int.random(in: 0 ..< 4, using: &rng) == 0 ? UInt32.random(in: 0 ... .max, using: &rng) : 8
            let offsetBytes = (0 ..< 4).map { UInt8(truncatingIfNeeded: ifd0 >> (8 * UInt32($0))) }
            bytes += littleEndian ? offsetBytes : offsetBytes.reversed()
            bytes += (0 ..< Int.random(in: 0 ..< 600, using: &rng)).map { _ in UInt8.random(in: 0 ... 255, using: &rng) }
            survive(Data(bytes), "random seed \(Self.seed) iteration \(iteration)")
        }
    }

    @Test func mutatedFixtures() throws {
        let fixtures = FixtureCatalogue.all.filter(\.isTIFF).filter { $0.id != "large-undefined" }
        let originals = fixtures.map { $0.build() }
        var rng = SplitMix64(seed: Self.seed &+ 1)
        for iteration in 0 ..< Self.iterations {
            let index = Int.random(in: 0 ..< originals.count, using: &rng)
            var bytes = [UInt8](originals[index])
            guard bytes.count > 8 else { continue }
            switch Int.random(in: 0 ..< 3, using: &rng) {
            case 0: // bit flips
                for _ in 0 ..< Int.random(in: 1 ... 8, using: &rng) {
                    let position = Int.random(in: 4 ..< bytes.count, using: &rng)
                    bytes[position] ^= 1 << UInt8.random(in: 0 ..< 8, using: &rng)
                }
            case 1: // truncation
                bytes = Array(bytes.prefix(Int.random(in: 0 ..< bytes.count, using: &rng)))
            default: // overwrite a 4-byte field with an arbitrary offset or count
                let position = Int.random(in: 4 ..< max(5, bytes.count - 4), using: &rng)
                let value = UInt32.random(in: 0 ... .max, using: &rng)
                for k in 0 ..< 4 where position + k < bytes.count {
                    bytes[position + k] = UInt8(truncatingIfNeeded: value >> (8 * UInt32(k)))
                }
            }
            survive(Data(bytes), "mutation seed \(Self.seed &+ 1) iteration \(iteration) of \(fixtures[index].id)")
        }
    }
}
