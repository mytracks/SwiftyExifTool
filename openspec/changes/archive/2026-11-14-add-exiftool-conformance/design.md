# Design

## Context

The synthetic fixtures already have a working conformance check, built by
`add-tiff-exif-reading`:

- `swift run fixtures snapshot` (`Sources/fixtures/Snapshotter.swift`)
  records `exiftool -j -a -G1 -u [-n]` and `-v2` for every TIFF fixture
  into `Tests/SwiftyExifToolTests/Snapshots/exiftool-13.55/`. It drops the
  `System` and `Composite` groups, `SourceFile` and `ExifTool` entries other
  than warnings and errors, and replaces strings longer than 1,024
  characters by a placeholder. An order-preserving JSON reader
  (`OrderedJSON`) keeps exiftool's repeated keys from `-a`.
- `Tests/SwiftyExifToolTests/Support/Snapshot.swift` holds `Snapshot`,
  `Deviations` and `Conformance.compare`, which compares tag lists, values
  (numbers within 1e-9 relative) and display texts, and skips values of
  unknown tags. `ConformanceTests` runs it as a gate.
  `FileTypeDetectionTests`, `ProvenanceTests` and `StringAndBlockTests` also
  load snapshots.
- The comparison reads `TagValue.exiftoolText`, which is internal and
  reachable only through `@testable import`. The public
  `TagValue.description` returns the same text.

Real files are much larger than fixtures. exiftool 13.55 prints about 2,150
entries for `_DSC0009.ARW` (most in Sony MakerNote groups such as
`SR2SubIFD` and `SR2DataIFD*`), while the library reports 116.

## Goals / Non-Goals

**Goals:**
- One comparison code path for fixtures, corpus and the command line.
- Corpus checks that are repeatable, need no exiftool to run, and keep
  personal data out of the repository.
- Report output useful for planning roadmap entries 4 to 14.

**Non-Goals:**
- Making the exiftool-shaped output a stable or public format.
- Decoding anything new in the library.
- Running the corpus in CI or downloading it during `swift test`.

## Decisions

### D1. A development target `ConformanceKit`

```
SwiftyExifTool (library, unchanged)
      ^
      |  public API only (no @testable)
ConformanceKit (target, no product)
      ^                    ^
      |                    |
fixtures (executable)   SwiftyExifToolTests
  + FixtureKit            + FixtureKit
```

`ConformanceKit` depends only on `SwiftyExifTool` and Foundation, plus
CryptoKit for SHA-256. The library's dependency rule does not apply to
development targets; CryptoKit exists on macOS and iOS, so the target
builds for both. It is not a product, so the package's consumers never see
it. It uses the public API: `Tag.group`, `name`, `isUnknown`, `value` (its
cases decide number versus string), `value.description` and `displayText`.

*Alternative:* keep everything in the test target, as today. Rejected,
because the command-line tool needs the same comparison. A public JSON API
in the library was rejected in exploration: the output is a measuring
instrument, not a contract.

### D2. Entries as the common data model

The comparison works on ordered lists of entries, `Entry(key: "Group:Name",
value: JSONValue)`, where `JSONValue` is a number, a string, or any other
JSON (arrays or objects, which exiftool can print for some tags; they are
kept as their JSON text). Both sides use this model: snapshots are parsed
with `OrderedJSON` (moved from the `fixtures` target), and reading results
are rendered as entries (`raw` with the numeric option, `display`
without). Repeated keys are matched by occurrence: the n-th `IFD0:X` on one
side pairs with the n-th on the other.

The renderer writes `.integer` and `.double` values as numbers. A string
value or display text is written as a number when it matches the JSON
number grammar (no leading zeros, optional fraction and exponent), so
`640` becomes a number while `0230` and `2.3.0.0` stay strings. exiftool's
own rule is observed, not known. The comparison tolerates a number on one
side and a numeric string on the other, as it does today, so the rule only
affects how readable `fixtures json` diffs are.

### D3. One comparison with two consumers

`Conformance.compare` moves to `ConformanceKit` without changing its rules
and returns a classification per paired key: matching, differing (value,
display text or both), missing or extra, plus an order flag.

- The **fixture gate** (`ConformanceTests`) turns every non-matching key
  that is not covered by `deviations.json`, and any order difference, into
  a failure. This is today's behaviour.
- The **corpus report and baseline** ignore order and use the per-key
  status. Real files differ from exiftool in the order of SubIFDs and
  MakerNotes for reasons that are not errors, and the baseline would
  otherwise churn.

### D4. Personal fields hashed at recording time

The rules live in one list in `ConformanceKit`:
- the names `Artist`, `Copyright` and `OwnerName` in any group;
- every name ending in `SerialNumber`;
- every key in the `GPS` group.

`corpus snapshot` replaces the value and display text of a matching entry
by `sha256:` followed by the lowercase hex SHA-256 of its text. The
comparison hashes the library's text in the same way for matching keys
before comparing. Numbers are hashed in a canonical text form with ten
significant digits (`%.10g`), the precision `exiftool -n` prints, so GPS
coordinates still match after rounding. The list grows when MakerNote
changes add personal fields; the hashing is checked by a test that loads
each corpus snapshot and finds no clear-text value for a listed key.

*Alternatives:* commit snapshots unchanged (rejected: the NEF sample alone
contains the photographer's e-mail address in Artist), or keep corpus
snapshots out of git (rejected: every run would then need exiftool, and
the results would depend on the local exiftool version).

### D5. Corpus layout and download

```
<package>/Corpus/manifest.json   committed
<package>/Corpus/<file>          git-ignored  (/Corpus/* , !/Corpus/manifest.json)
   or $SWIFTYEXIF_CORPUS/<file>
```

Each manifest entry has `id`, `fileName`, `url`, `licence` (`CC0-1.0`),
`sha256`, `camera`, `format` and `source` (the raw.pixls.us page). The
manifest reader rejects any licence other than CC0.

`fixtures corpus fetch` downloads with `URLSession` into a temporary file,
hashes it in 1 MiB chunks, and moves it into the corpus directory only when
the SHA-256 matches. Files that are already present with the right checksum
are skipped. Tests find the corpus directory through `#filePath` of the
test sources, or through `SWIFTYEXIF_CORPUS`. They never use the network.

### D6. Corpus snapshots and baseline

```
Tests/SwiftyExifToolTests/Snapshots/
  exiftool-13.55/<fixture>.json       synthetic fixtures (unchanged)
  deviations.json                     deliberate deviations (unchanged)
  corpus/exiftool-13.55/<id>.json     raw + display, hashed personal fields,
                                      commands, file sha256; no -v2
  corpus/baseline.json                { id: [ {key, occurrence, status} ] }
```

`corpus snapshot` writes one snapshot per manifest entry. It replaces
older `corpus/exiftool-*` directories, as the fixture snapshotter does,
and refuses files whose checksum does not match. The verbose output is not
recorded: for RAW files it is large and repeats values, personal ones
included. `corpus baseline` writes the current status of every key of every
present corpus file, sorted by file, key and occurrence, so diffs stay
readable. It contains no values. Snapshots and baseline are a few hundred
kilobytes in total.

The baseline test (`CorpusBaselineTests`) is parameterized over the
manifest entries whose files are present. When none is present, a single
test is disabled with a note that names `swift run fixtures corpus fetch`.
For each present file it checks the SHA-256 first, then compares statuses
and lists the keys whose status changed.

### D7. Command line

```
swift run fixtures generate                 (existing)
swift run fixtures snapshot                 (existing, now via ConformanceKit)
swift run fixtures json <file> [-n]         exiftool-shaped JSON
swift run fixtures corpus fetch
swift run fixtures corpus snapshot          needs exiftool
swift run fixtures corpus check             report: per file and group
swift run fixtures corpus baseline          re-record the baseline
```

The report prints one line per group with the counts of matching,
differing, missing and extra keys, then the non-matching keys. The tool
stays macOS-only (`Process`, `URLSession` downloads), as today.

### D8. Bounded reading and memory

`ConformanceKit` reads files only through `MetadataReader`, whose reads
are bounded (see the `tiff-container` and `metadata-reading-api` specs), so
a 25 MB RAW file is never loaded whole. Checksums are computed in 1 MiB
chunks. Neither the library nor the app changes, so iOS is unaffected.

## Sources

No tag or format knowledge is added. All exiftool data comes from black-box
observation of exiftool 13.55 on individual files (`docs/clean-room.md`):
- the committed synthetic fixtures;
- the four CC0 samples from raw.pixls.us: Nikon D750, Sony ILCE-7M3, and
  Canon EOS 5D Mark III for both the CR2 and the DNG.

Each snapshot records the exiftool version and commands as provenance.

## Risks / Trade-offs

- [exiftool updates change many snapshots at once] → Snapshots live in
  version-named directories and are re-recorded together, so an update is
  one reviewable diff.
- [The baseline changes with every library change that touches corpus
  tags] → This is intended: the diff shows the progress. Order is ignored,
  so only real changes cause churn.
- [Hashing hides values in diffs] → Only listed personal fields are
  hashed. For debugging, `fixtures json` and exiftool can be run locally on
  the file.
- [raw.pixls.us moves or removes a file] → The SHA-256 detects any
  replacement. The manifest is updated with a new URL, or the entry is
  dropped together with its snapshot.
- [Corpus snapshots expose exiftool's names for MakerNote tags] → They are
  observations of individual files, which `docs/clean-room.md` allows. Using
  such a name in the library still needs a recorded observation, as today.
- [Number rendering differs from exiftool for edge cases] → It affects only
  the readability of `fixtures json`; the comparison accepts numbers and
  numeric strings on either side.

## Migration Plan

Development tooling only; no data migration. The existing synthetic
snapshots and `deviations.json` keep their format. Rolling back means
removing the target and the corpus files.
