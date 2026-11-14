# Spec Delta

## Purpose

Development tooling that measures how closely the library's reading results
match exiftool's black-box output: on committed synthetic fixtures as a
strict gate, and on a sample corpus of real camera files as a recorded
report. It never affects the library's public API.

## ADDED Requirements

### Requirement: exiftool-shaped output

The tooling SHALL render a reading result as the members of the object that `exiftool -j -a -G1 -u` prints for the same file, or `exiftool -j -a -G1 -u -n` with the numeric option. Members SHALL use `Group:Name` keys in the library's traversal order and keep repeated keys. With the numeric option each value SHALL be the tag's value, otherwise its display text.

#### Scenario: Numeric and display output
- **WHEN** the fixture `basic-le` is rendered with and without the numeric option
- **THEN** `IFD0:Orientation` is the number 6 with it and the string `Rotate 90 CW` without it, and `IFD0:ImageWidth` is the number 640 in both

#### Scenario: Matches exiftool on a fixture
- **WHEN** the fixture `basic-le` is rendered with the numeric option
- **THEN** its keys and values equal the `raw` entries of the fixture's exiftool snapshot

#### Scenario: Printed from the command line
- **WHEN** `swift run fixtures json <file> -n` runs on a fixture
- **THEN** it prints a JSON array with one object containing exactly the rendered members

### Requirement: JSON value types and compared groups

A rendered value or display text that is a decimal number SHALL be written as a JSON number, anything else as a JSON string. The `System` and `Composite` groups, `SourceFile`, and `ExifTool` members other than warnings and errors SHALL NOT appear, in rendered output or in snapshots, because they are outside the library's scope.

#### Scenario: Rational shown as a fraction
- **WHEN** ExposureTime of `basic-le` is rendered without the numeric option
- **THEN** it is the string `1/250`, and with the numeric option the number 0.004

#### Scenario: No file-system group
- **WHEN** any fixture is rendered
- **THEN** no key starts with `System:` or `Composite:` and there is no `SourceFile` member

### Requirement: Comparison with a snapshot

The tooling SHALL compare a reading result with an exiftool snapshot and report each difference with its `Group:Name` key and kind: a missing tag, an extra tag, a different order, a different value or a different display text. Numbers SHALL be equal when they differ by at most 1e-9 relative to the larger value. For tags flagged as unknown only the key SHALL be compared. A difference that a documented deviation covers SHALL NOT be reported.

#### Scenario: Wrong display text
- **WHEN** the display text of Orientation in the fixture `tiff-orientation` is replaced by `Rotate 90 CCW` before comparing
- **THEN** exactly one difference is reported: `IFD5:Orientation`, kind display text, expected `Rotate 90 CW`

#### Scenario: Missing tag
- **WHEN** IFD0:Make is removed from the result of `basic-le` before comparing
- **THEN** a missing tag `IFD0:Make` is reported

### Requirement: Documented deviations

Each deliberate deviation from exiftool SHALL be recorded with the fixture (or all fixtures), the tag key or key pattern, a reason and the spec requirement that sanctions it. Deviations SHALL describe intended behaviour only. Gaps that later roadmap entries close SHALL be recorded in the corpus baseline instead.

#### Scenario: Latin-1 artist
- **WHEN** the fixture `strings` is compared
- **THEN** `IFD0:Artist` is not reported, because a deviation for it cites `exif-tags: Strings`

### Requirement: Synthetic fixture gate

Every committed TIFF fixture SHALL have an exiftool snapshot. The test suite SHALL fail when the comparison reports any difference for a fixture. It SHALL run without exiftool installed and without network access.

#### Scenario: Undocumented difference fails the tests
- **WHEN** the library's display text for a fixture tag differs from the snapshot and no deviation covers it
- **THEN** `swift test` fails and names the fixture and the difference

### Requirement: Sample corpus manifest

The sample corpus SHALL be described by a committed manifest. Each entry SHALL give an identifier, the file name, the download URL, the licence, the SHA-256 of the file, the camera and the format. Only files licensed CC0 SHALL be listed. The sample files themselves SHALL NOT be committed.

#### Scenario: Starting corpus
- **WHEN** the manifest is read
- **THEN** it lists the CC0 files `compressed_14_bit.NEF`, `_DSC0009.ARW`, `5G4A9394.CR2` and `compress.dng` from raw.pixls.us with their checksums

#### Scenario: Licence other than CC0
- **WHEN** a manifest entry has a licence other than CC0
- **THEN** reading the manifest fails and names the entry

### Requirement: Corpus location and download

The corpus SHALL be kept in the git-ignored directory `Corpus/` of the package, or in the directory named by the environment variable `SWIFTYEXIF_CORPUS` when it is set. `swift run fixtures corpus fetch` SHALL download every listed file that is missing or whose checksum does not match, and SHALL keep a file only when its SHA-256 equals the manifest's.

#### Scenario: Fetch skips valid files
- **WHEN** `corpus fetch` runs and a listed file is already present with the right checksum
- **THEN** that file is not downloaded again

#### Scenario: Checksum mismatch
- **WHEN** a downloaded file's SHA-256 differs from the manifest
- **THEN** the file is not kept and the command fails, naming the file

### Requirement: Corpus snapshots

`swift run fixtures corpus snapshot` SHALL record, for every corpus file, the output of `exiftool -j -a -G1 -u -n` and `exiftool -j -a -G1 -u`, filtered as for the exiftool-shaped output. Snapshots SHALL be committed in a directory named after the exiftool version, together with the commands used, as provenance for black-box observations. Recording SHALL require exiftool; reading snapshots SHALL NOT.

#### Scenario: Version-named snapshots
- **WHEN** the corpus snapshots are recorded with exiftool 13.55
- **THEN** one snapshot per corpus file is written under a directory named `exiftool-13.55`, and it lists the exiftool commands used

### Requirement: Personal fields are hashed

In corpus snapshots, the value and display text of personal fields SHALL be stored as `sha256:` followed by the lowercase hex SHA-256 of the field's text, never in clear text. Personal fields are at least Artist, Copyright, OwnerName, every tag whose name ends in SerialNumber, and every tag in the GPS group. The comparison SHALL hash the library's text for these fields the same way before comparing.

#### Scenario: Artist of the NEF sample
- **WHEN** the snapshot of `compressed_14_bit.NEF` is recorded
- **THEN** `IFD0:Artist` is stored as a `sha256:` value and the snapshot file does not contain the artist's text

#### Scenario: Hashed fields still compare
- **WHEN** the library reads the same Artist text as exiftool
- **THEN** the comparison reports no difference for `IFD0:Artist`

### Requirement: Corpus report

`swift run fixtures corpus check` SHALL report, for each present corpus file and each group, the number of matching, differing, missing and extra tags, followed by the differing, missing and extra keys. Files that are absent SHALL be listed as skipped.

#### Scenario: Groups the library does not read yet
- **WHEN** `corpus check` runs on `_DSC0009.ARW`
- **THEN** the tags of groups the library does not produce yet are counted as missing for those groups

### Requirement: Corpus baseline

A committed baseline SHALL record, for each corpus file, the status (matching, differing, missing or extra) of every compared key, and no tag values. `swift run fixtures corpus baseline` SHALL re-record it. The test suite SHALL compare the current status of every present corpus file with the baseline and fail on any difference, improvements included.

#### Scenario: Improvement must be recorded
- **WHEN** a library change makes a previously missing corpus tag match
- **THEN** the baseline test fails and names the key, until the baseline is re-recorded

#### Scenario: Corpus absent
- **WHEN** `swift test` runs and no corpus file is present
- **THEN** the baseline test is skipped with a note on how to fetch the corpus, and the rest of the suite runs

#### Scenario: Corpus file with wrong checksum
- **WHEN** a corpus file is present but its SHA-256 differs from the manifest
- **THEN** the baseline test fails and names the file
