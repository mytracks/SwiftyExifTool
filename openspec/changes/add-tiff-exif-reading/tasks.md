# Tasks

## 1. Package scaffold

- [x] 1.1 Create `Package.swift` (tools 6.0, Swift 6 language mode, platforms macOS 14 / iOS 17) with the library product `SwiftyExifTool`, the internal target `FixtureKit`, the executable target `fixtures` and the test target `SwiftyExifToolTests` with `Fixtures/` and `Snapshots/` as resources, per design D1; verify `swift build` succeeds and `swift test` runs an empty placeholder test.
- [x] 1.2 Verify the library builds for iOS with `xcodebuild -scheme SwiftyExifTool -destination 'generic/platform=iOS' build`, and that the `fixtures` tool compiles to a stub on non-macOS platforms (`#if os(macOS)` around `Process`).

## 2. Byte sources and binary reader

- [x] 2.1 Implement `ByteSource`, `DataByteSource` and `FileByteSource` (read-only FileHandle, 64 KiB page cache, closed after each read call) per design D2; verify with unit tests for reads at the start, middle and end of a file and for out-of-range reads failing with an error (`swift test --filter ByteSourceTests`).
- [x] 2.2 Implement `BinaryReader` with byte order, base offset and overflow-checked bounds checks for 8/16/32/64-bit integers, floats and byte ranges per design D3; verify `swift test --filter BinaryReaderTests` covers both byte orders, offsets near `Int.max`, and zero-length reads.
- [x] 2.3 Add an internal counting wrapper around `ByteSource` that records bytes read, for the bounded-reading test in 7.3; verify with a unit test that the count matches known reads.

## 3. Fixture kit

- [x] 3.1 Implement `TIFFBuilder` in `FixtureKit`: both byte orders, chained IFDs, SubIFD/Exif/GPS/Interop pointers, entries of every field type including UTF-8 (129), out-of-line values laid out automatically, and raw byte patches for malformed cases; verify `swift test --filter TIFFBuilderTests` checks the emitted bytes of a two-entry IFD against a hand-written byte array.
- [x] 3.2 Create the fixture catalogue with the structural fixtures the specs name (basic LE/BE, all field types, IFD chain, two SubIFDs, Exif+GPS+Interop, unknown field type, unknown tags, out-of-bounds pointer, truncated IFD0, self-linked IFD0, too many IFDs, 1 MiB UNDEFINED value, value beyond EOF, padded and non-UTF-8 strings, embedded blocks) and the signature fixtures (BigTIFF, JPEG, PNG, ISO BMFF, text, empty); verify each catalogue entry has a unique ID and a one-line purpose.
- [x] 3.3 Implement `swift run fixtures generate` writing all catalogued fixtures to `Tests/SwiftyExifToolTests/Fixtures/synthetic/`; commit the files and verify the test `FixtureDriftTests` regenerates every fixture in memory and finds it byte-identical to the committed file.
- [x] 3.4 Implement `swift run fixtures snapshot` per design D7 (`-j -a -G1 -u -n`, `-j -a -G1 -u`, `-v2`; System/ExifTool groups dropped except warnings; exiftool version and commands stored); record and commit snapshots for all TIFF fixtures with exiftool 13.55, and verify the tool refuses to run with a clear message when exiftool is not on `PATH`.
- [x] 3.5 Add the observation rule of design D7 (fixtures only contain spec-sourced tag IDs, no ID enumeration) to `docs/clean-room.md`, and the fixture and snapshot commands to `CLAUDE.md`; verify both commands run as documented.

## 4. File type detection

- [x] 4.1 Implement signature detection for TIFF (both byte orders), BigTIFF, JPEG, PNG and ISO BMFF with major brand, independent of the file name; verify `swift test --filter FileTypeDetectionTests` covers every scenario of the file-type-detection spec, including the misleading extensions, the empty file and the text file.
- [x] 4.2 Produce the `File` group tags FileType, FileTypeExtension, MIMEType and ExifByteOrder with their values and display texts; verify against the snapshots of the basic LE and BE fixtures.

## 5. TIFF container

- [x] 5.1 Implement header parsing and the IFD entry reader for all field types with inline and out-of-line values, overflow-checked size computation, and value-location reporting (entry offset, value offset, length); verify `swift test --filter TIFFEntryTests` covers the field-type, UTF-8, inline/offset and value-location scenarios of the tiff-container spec.
- [x] 5.2 Implement the directory walker: IFD chain groups, ExifIFD/GPS/InteropIFD/SubIFD pointers and groups, traversal order, pointer entries omitted from tags, and the directory list; verify `swift test --filter TIFFWalkerTests` covers the chain, sub-directory, traversal-order and directory-list scenarios.
- [x] 5.3 Implement the failure handling: unknown field types, values beyond EOF, directories whose table does not fit, out-of-bounds pointers, cycle detection, and `ReadingLimits` (directories, depth, loaded value size) per design D4; verify `swift test --filter TIFFRobustnessTests` covers each such scenario of the tiff-container spec with the exact warnings expected.

## 6. Reading API and result model

- [x] 6.1 Implement the public model (`Metadata`, `Tag`, `TagGroup`, `StoredValue`, `TagValue`, `ValueLocation`, `Directory`, `ReadWarning`, `ReadError`, `ReadingLimits`) per design D5, all `Sendable` and `Hashable`, with DocC comments including the security-scoped access note and the `default`-branch advice; verify `swift build` and that `swift package generate-documentation` (or an `xcodebuild docbuild`) emits no missing-documentation warnings for public symbols.
- [x] 6.2 Implement `MetadataReader.read(contentsOf:limits:)` and `read(data:limits:)` with typed throws, wiring detection, the walker and the tag tables; verify `swift test --filter ReadingAPITests` covers the URL, data, file-untouched, data-equals-file, errors (missing file, PNG, broken TIFF) and determinism scenarios of the metadata-reading-api spec.
- [x] 6.3 Implement tag lookup by group and name and by name alone; verify with the lookup scenarios of the metadata-reading-api spec.

## 7. Standard tags

- [x] 7.1 Implement the tag definition type, the `main` and `gps` tables with lookup, the display-conversion cases of design D6 and the `Unknown (<value>)` fallback, plus unknown-tag naming (`Exif_0x…`, `GPS_0x…`); verify with the table-per-directory, unknown-value and unknown-tag scenarios of the exif-tags spec.
- [x] 7.2 Add the TIFF 6.0 baseline and extension tags with specification provenance, catalogue fixtures covering every tag and every enumerated value, re-record snapshots, and confirm exiftool names (e.g. ImageHeight); verify the conformance test passes for these fixtures.
- [x] 7.3 Add the Exif IFD tags of CIPA DC-008-2026 (Exif 3.1) with provenance, fixtures for every enumerated and bit-field value (one value per chained IFD, design D7) and for the formatted values (exposure time, F-number, focal length, exposure bias, versions, components configuration, user comment), re-record snapshots; verify the conformance test passes.
- [x] 7.4 Add the GPS tags (one fixture per enumerated value; coordinate, altitude, timestamp and datestamp formatting) and the Interoperability tags with provenance, re-record snapshots; verify the conformance test passes.
- [x] 7.5 Add string decoding (trailing NUL and space stripping, UTF-8, ISO 8859-1 fallback) and the embedded-block tags (0x02BC, 0x927C, 0x83BB, 0x8773) as undecoded binary tags, with the Latin-1 and hidden-block entries in `deviations.json`; verify the strings and embedded-blocks scenarios of the exif-tags spec.
- [x] 7.6 Add the provenance test of design D6: every definition has a specification source and appears in at least one snapshot or is listed as hidden; verify `swift test --filter ProvenanceTests` passes and fails when a definition's source is removed.
- [x] 7.7 Implement the snapshot conformance test (groups, names, values with 1e-9 relative tolerance, display texts, deviations applied) over all committed fixtures; verify it passes and that an intentionally wrong display text in a test copy of a definition makes it fail with a readable diff.

## 8. Robustness and resource guarantees

- [x] 8.1 Implement the seeded fuzz test of design D8 over random-after-header files and mutated fixtures, with the iteration count overridable by an environment variable; verify `swift test --filter FuzzTests` passes with the default count and with 100,000 iterations locally.
- [x] 8.2 Implement the bounded-reading test: a 200 MB sparse temporary file with a small TIFF header and IFD0, read through the counting source; verify it reads less than 1 MB.
- [x] 8.3 Implement the concurrency test reading 50 fixtures concurrently in a task group and comparing with sequential results; verify it passes under `swift test` with Thread Sanitizer (`swift test --sanitize=thread --filter ConcurrencyTests`).

## 9. Integration

- [x] 9.1 Run the full suite on macOS (`swift test`) and on an iOS simulator (`xcodebuild test -scheme SwiftyExifTool-Package -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`), with fixtures loaded as bundle resources on both; verify both pass.
- [x] 9.2 Read a few real TIFF-based RAW files from the maintainer's local library (not committed) and compare by eye with `exiftool -a -G1` for the standard groups; record findings that need new deviations or tag fixes as follow-ups in the change notes, without committing the files.
- [x] 9.3 Update `README.md` (status, minimal usage example) and verify the example compiles as a documentation snippet test.

## Workflow follow-up

- Archive the change with `/opsx:archive` after review, which also sets roadmap entry 1 to `done` in `docs/roadmap.md`.
