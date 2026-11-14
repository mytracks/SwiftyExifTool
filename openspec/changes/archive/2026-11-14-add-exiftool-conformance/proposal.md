# Proposal

## Why

The next roadmap entries add formats (DNG, CR2, NEF, ARW, CR3, RAF) and
MakerNotes. Each needs a repeatable measure of how far the library's output
is from exiftool's on real camera files. Today only the synthetic fixtures
are compared, inside the test target. The two real-file checks so far were
done by hand with downloaded samples and are not repeatable. This change
implements roadmap entry 3, `add-exiftool-conformance`, as a measuring
instrument for development. It is not a library feature.

## What Changes

- New development-only target `ConformanceKit`. It turns a reading result
  into the entry list that `exiftool -j -a -G1 -u [-n]` would print and
  compares it with a recorded exiftool snapshot. The comparison that is now
  in the tests' support code (`Tests/SwiftyExifToolTests/Support/Snapshot.swift`)
  moves here, so synthetic fixtures, the sample corpus and the command-line
  output share one code path. The library's public API does not change.
- `swift run fixtures json <file> [-n]` prints a reading result as
  exiftool-shaped JSON, for a direct `diff` against exiftool.
- Sample corpus of real files, kept outside git:
  - a committed manifest lists each file with its URL, licence (CC0 only),
    SHA-256 and camera;
  - `swift run fixtures corpus fetch` downloads the files into the
    git-ignored `Corpus/` directory, or into `SWIFTYEXIF_CORPUS`, and checks
    their checksums;
  - the starting corpus is the four CC0 samples of the earlier checks (NEF,
    ARW, CR2 and DNG from raw.pixls.us).
- `swift run fixtures corpus snapshot` records exiftool's output for the
  corpus into a committed, version-named snapshot directory. Personal
  fields, such as the artist, serial numbers and GPS data, are stored as
  SHA-256 hashes, never in clear text.
- `swift run fixtures corpus check` prints a report per file and group:
  matching, differing, missing and extra tags. A committed baseline records
  this status for every corpus tag. A test compares the current result with
  the baseline: any change, an improvement included, has to be recorded
  deliberately. Without the corpus, the test is skipped.
- Synthetic fixtures remain a strict gate in `swift test`, as today.
  `deviations.json` keeps listing only deliberate deviations; gaps in real
  files belong in the baseline.
- `docs/roadmap.md`: entry 3 drops the library capability
  `metadata-json-export` and names `exiftool-conformance` instead.

### Scope

- **Formats in scope:** every format the library reads; the corpus starts
  with TIFF-based NEF, ARW, CR2 and DNG. Later format changes add their
  samples to the manifest.
- **Groups compared:** every group exiftool prints with `-j -a -G1 -u`,
  except `System`, `Composite`, `SourceFile` and `ExifTool` entries other
  than warnings and errors. This filter is the one already used for the
  synthetic snapshots. Groups the library does not produce yet, such as
  MakerNotes, show up in the report as missing.
- **Out of scope:**
  - a public JSON export in the library or the app;
  - CI integration;
  - exiftool's verbose (`-v`) and binary (`-b`) output for corpus files;
  - committing sample files themselves;
  - non-CC0 samples.

## Capabilities

### New Capabilities

- `exiftool-conformance`: the development tooling that measures the
  library against exiftool. It covers exiftool-shaped output, comparison
  with snapshots and deviations, the synthetic fixture gate, the sample
  corpus (manifest, download and checksums), corpus snapshots with hashed
  personal fields, and the report with its baseline.

### Modified Capabilities

None. The `exif-tags` requirement "Conversions match observations" keeps
its behaviour; only the code that checks it moves into `ConformanceKit`.

## Impact

- New: the target `ConformanceKit`; `Corpus/manifest.json`; corpus
  snapshots and the baseline under `Tests/SwiftyExifToolTests/Snapshots/`;
  new subcommands of the `fixtures` executable.
- Changed:
  - `Package.swift` adds the target and its dependencies;
  - `.gitignore` ignores the corpus files and keeps the manifest;
  - `ConformanceTests` and the other tests that load snapshots use
    `ConformanceKit`;
  - `docs/roadmap.md` (entry 3) and `CLAUDE.md` gain the new commands.
- Unchanged: the public API of `SwiftyExifTool` and the SwiftyExif app.
- Dependencies: none at run time. exiftool (`brew install exiftool`) is
  needed only to record snapshots, and network access only for
  `corpus fetch`.
