# Tasks

## 1. ConformanceKit and migration of the existing comparison

- [x] 1.1 Add the target `ConformanceKit` (depends on `SwiftyExifTool`; no product) per design D1. Make `fixtures` and `SwiftyExifToolTests` depend on it. Verify with `swift build` and `swift build --target ConformanceKit`.
- [x] 1.2 Move `OrderedJSON` (from `Sources/fixtures/Snapshotter.swift`) and `Snapshot`, `Deviations` and `Conformance` (from `Tests/SwiftyExifToolTests/Support/Snapshot.swift`) into `ConformanceKit` without changing their rules. Use only the public library API (`value.description` instead of `exiftoolText`). Keep `FixtureFiles` in the tests and pass it the snapshot directory. Verify that `swift test` passes in full, including `ConformanceTests`, `ConformanceSelfTests`, `FileTypeDetectionTests`, `ProvenanceTests` and `StringAndBlockTests`.
- [x] 1.3 Make `swift run fixtures snapshot` use `ConformanceKit`. Verify that re-recording with exiftool 13.55 leaves `git diff Tests/SwiftyExifToolTests/Snapshots` empty.
- [x] 1.4 Update `docs/roadmap.md` entry 3: replace `metadata-json-export` by `exiftool-conformance`, mark the output as a development instrument, set the status to `in progress`, and record the decisions on the two "To settle" items. Verify by reading the entry against proposal.md.

## 2. Entries, rendering and comparison

- [x] 2.1 Add `Entry` and `JSONValue` (number, string, other JSON kept as text) and the renderer from a reading result to `raw` and `display` entries, with the number rule and the group filter of design D2. Verify with unit tests for the scenarios "Numeric and display output", "Rational shown as a fraction" and "No file-system group" on `basic-le`, and "Matches exiftool on a fixture": the rendered `raw` entries of `basic-le` equal its snapshot.
- [x] 2.2 Rebuild `Conformance.compare` on entries per design D3: pairing by key and occurrence, a per-key classification (matching, differing value or display, missing, extra), an order flag, hashing hooks for later use, and the existing tolerance and unknown-tag rules. The fixture gate keeps failing on any uncovered difference and on order differences. Verify with `swift test --filter Conformance`: all fixtures pass, plus the scenarios "Wrong display text" (`tiff-orientation`), "Missing tag" (`basic-le` without IFD0:Make), "Latin-1 artist" (`strings`) and a new test with two repeated keys paired by occurrence.
- [x] 2.3 Add `swift run fixtures json <file> [-n]` per design D7 and document it in `CLAUDE.md`. Verify the scenario "Printed from the command line" on `basic-le`, and compare its output for `tiff-orientation` with `exiftool -j -a -G1 -u -n`: the same keys and values once `System`, `Composite`, `SourceFile` and other `ExifTool` entries are dropped (exiftool comparison).

## 3. Corpus manifest and download

- [x] 3.1 Add `Corpus/manifest.json` with the four CC0 samples (id, file name, URL, licence `CC0-1.0`, SHA-256, camera, format, source page) and a manifest reader that rejects any other licence. Verify with unit tests for "Starting corpus" (the committed manifest) and "Licence other than CC0" (an in-memory manifest).
- [x] 3.2 Ignore `/Corpus/*` except `/Corpus/manifest.json` in `.gitignore`. Add corpus directory resolution: `SWIFTYEXIF_CORPUS`, otherwise `Corpus/` found from the package root through `#filePath`. Verify with a unit test of the resolution with and without the variable, and check that `git status` does not list downloaded corpus files.
- [x] 3.3 Add `swift run fixtures corpus fetch` per design D5: download to a temporary file, hash in 1 MiB chunks, keep the file only when the checksum matches, and skip files that are already valid. Document it in `CLAUDE.md`. This needs network access, about 70 MB. Verify by command checks:
  - into an empty directory (`SWIFTYEXIF_CORPUS`) it downloads 4 files;
  - a second run skips all of them ("Fetch skips valid files");
  - a temporary manifest with a wrong checksum fails, names the file and keeps nothing ("Checksum mismatch").

## 4. Personal fields and corpus snapshots

- [x] 4.1 Add the personal-field list and hashing of design D4 (`sha256:` plus lowercase hex, numbers in `%.10g` form) and hash both sides in the comparison for listed keys. Verify with unit tests: key patterns (`IFD0:Artist`, `ExifIFD:BodySerialNumber`, every `GPS:` key, but not `IFD0:Make`), canonical number text, and "Hashed fields still compare" for an Artist text.
- [x] 4.2 Add `swift run fixtures corpus snapshot` per design D6: one snapshot per present manifest entry under `Snapshots/corpus/exiftool-<version>/`, with commands and file SHA-256 and no `-v2`. It replaces older versions and refuses files with a wrong checksum. Record and commit the four snapshots, and document the command in `CLAUDE.md`. Verify the scenario "Version-named snapshots", and add a test that loads every committed corpus snapshot and finds only `sha256:` values for listed keys ("Artist of the NEF sample").
- [x] 4.3 Add a short note to `docs/clean-room.md` (section Fixtures) that corpus snapshots store personal fields only as hashes. Verify that the note names the field list's location in `ConformanceKit`.

## 5. Corpus report and baseline

- [x] 5.1 Add `swift run fixtures corpus check` per design D7: counts per file and group, then the non-matching keys, with absent files listed as skipped. Document it in `CLAUDE.md`. Verify "Groups the library does not read yet": for `_DSC0009.ARW`, the Sony MakerNote groups (e.g. `SR2SubIFD`) are counted as missing.
- [x] 5.2 Add `swift run fixtures corpus baseline`, which writes `Snapshots/corpus/baseline.json` (status per file, key and occurrence, sorted, no values) per design D6. Record and commit the baseline and document the command in `CLAUDE.md`. Verify that the file contains no values and that re-running it leaves `git diff` empty.
- [x] 5.3 Add `CorpusBaselineTests` per design D6. Verify:
  - with the corpus present, `swift test --filter CorpusBaseline` passes;
  - with `SWIFTYEXIF_CORPUS` pointing to an empty directory, the test is skipped with the note naming `corpus fetch` ("Corpus absent");
  - a baseline entry changed by hand fails and names the key ("Improvement must be recorded");
  - a corpus copy with one changed byte fails and names the file ("Corpus file with wrong checksum").

## 6. Integration

- [x] 6.1 Run `swift test` with and without the corpus, the library iOS build (`xcodebuild -scheme SwiftyExifTool -destination 'generic/platform=iOS' build`), and the SwiftyExif app tests on macOS (`CLAUDE.md` command). Verify that all pass and that the library's public API is unchanged (`git diff Sources/SwiftyExifTool` is empty).

## Workflow follow-up

- Archive the change with `/opsx:archive` after review; this also sets roadmap entry 3 to `done` in `docs/roadmap.md`.
