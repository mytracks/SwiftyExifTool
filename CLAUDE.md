# CLAUDE.md

Guidance for Claude Code in this repository.

## Project

SwiftyExifTool: a Swift package that reads and writes metadata, mainly in
camera RAW files, on macOS, iOS and iPadOS, plus the Inspector debug app.
Scope, order of work and capability names: `docs/roadmap.md`.

## Language

- Talk to the maintainer in German.
- Write everything in the repository in English: code, comments, docs and
  OpenSpec artifacts.

## Clean-room rules (binding)

Read `docs/clean-room.md` before working on tags or formats. In particular:

- Never open, fetch or search ExifTool's source, its TagNames documentation,
  or Exiv2/libexif/LibRaw/dcraw code, locally or on the web. Do not run
  `exiftool -listx` or other tag database dumps.
- Running exiftool on individual fixture files (`-j -a -G1 [-n]`, `-v3`,
  `-htmldump`, `-validate`) is allowed and is the main way to learn
  non-standard tags.
- Your own recollection of tag tables is not a source. Confirm against a
  published specification or a black-box observation, record the
  provenance, or stop and ask.

## Workflow

- Changes go through OpenSpec: `/opsx:explore`, `/opsx:propose`,
  `/opsx:apply`, `/opsx:archive`. Every behaviour change goes through a
  change; implement only tasks from an applied change.
- Project constraints for all artifacts live in `openspec/config.yaml`.
- When archiving, update the change's status in `docs/roadmap.md`.

## Engineering constraints

- Swift 6 language mode, strict concurrency; public types are `Sendable`.
- Library: Swift standard library and Foundation only. No third-party
  packages, no ImageIO/CoreGraphics metadata APIs, nothing unavailable on
  iOS (e.g. `Process`).
- Parsers are bounds-checked and never trap on bad input: no force unwraps,
  unchecked subscripts or unbounded recursion on file data.
- Do not load whole RAW files into memory.
- Tests use Swift Testing (`import Testing`).
- Never commit large sample RAW files or personal photos.

## Commands

- Build the library: `swift build`
- Run the tests: `swift test`
- Build for iOS: `xcodebuild -scheme SwiftyExifTool -destination 'generic/platform=iOS' build`
- Regenerate the synthetic fixtures after changing the catalogue in
  `Sources/FixtureKit/`: `swift run fixtures generate`
- Re-record the exiftool snapshots (needs exiftool on `PATH`):
  `swift run fixtures snapshot`. Review the diff: it is the provenance of
  names and conversions.
- Print a file's reading result like `exiftool -j -a -G1 -u [-n]`, for a
  direct diff against exiftool: `swift run fixtures json <file> [-n]`.
- Sample corpus of real CC0 files (listed in `Corpus/manifest.json`, kept
  out of git in `Corpus/` or `$SWIFTYEXIF_CORPUS`):
  - Download and verify it (about 70 MB): `swift run fixtures corpus fetch`
  - Re-record its exiftool snapshots (needs exiftool; personal fields are
    stored as hashes): `swift run fixtures corpus snapshot`
  - Report matching, differing, missing and extra tags per file and group:
    `swift run fixtures corpus check`
  - Re-record the committed baseline after a change that affects corpus
    results (the baseline test fails until then; review the diff):
    `swift run fixtures corpus baseline`
- SwiftyExif app (needs XcodeGen, `brew install xcodegen`):
  - Generate the project: `xcodegen generate --spec App/project.yml`
    (rerun after adding or removing files under `App/`)
  - Build and test on macOS:
    `xcodebuild -project App/SwiftyExif.xcodeproj -scheme SwiftyExif -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test`
  - Build and test on iOS:
    `xcodebuild -project App/SwiftyExif.xcodeproj -scheme SwiftyExif -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test`
  - The `CODE_SIGN_*` overrides sign ad hoc, because command-line sessions
    cannot use the signing key in the keychain. Xcode uses automatic signing
    with team 4TNB35NY7G.
