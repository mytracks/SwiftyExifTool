# Proposal

## Why

Every later roadmap entry (RAW formats, XMP, MakerNotes, writing) needs a
fast way to see what the library actually extracts from a real file: which
tags, in which group, with which stored value, value, display text and
offset, and which warnings. Today that requires writing a test. This change
implements roadmap entry 2, `add-inspector-app`: a debug app named
**SwiftyExif** for macOS, iOS and iPadOS.

## What Changes

- Add the SwiftUI app **SwiftyExif** (bundle identifier
  `info.stichling.SwiftyExif`) as one multiplatform target for macOS 14,
  iOS 17 and iPadOS 17. It depends on the local `SwiftyExifTool` package and
  on nothing else.
- Maintain the Xcode project with XcodeGen: a committed `App/project.yml`
  generates `App/SwiftyExif.xcodeproj`, which is not committed.
- Open a file with the system file picker on all platforms, by drag and drop
  (macOS, iPadOS), and with "Open With" from Finder on macOS. Files are only
  read; the app never writes to them.
- Show the result of `MetadataReader` for the open file:
  - a summary (file name, size, file type, byte order, tag and warning counts);
  - every tag, grouped by its group in traversal order, with name, tag ID in
    hex, field type, count, value, display text and value offset;
  - details of a selected tag, including the lossless stored value, the
    value location and whether the tag is unknown;
  - the directory list and all warnings;
  - read errors (unsupported or unknown format, file access) instead of tags.
- Search across names, values and display texts; filter by group and hide
  unknown tags; copy a value, a display text or a whole row.
- Add unit tests for the app's presentation logic and document the build
  commands in `CLAUDE.md`.

### Scope

- **Formats and groups in scope:** whatever the library reads. That is
  currently TIFF-structured files, including DNG, CR2, NEF and ARW, and the
  groups `File`, `IFD0`…, `SubIFD`…, `ExifIFD`, `GPS` and `InteropIFD`. The app
  shows groups generically, so groups added by later changes appear without
  app changes.
- **Out of scope:** editing or writing metadata, comparing with exiftool
  inside the app, hex views, image previews or thumbnails, several files side
  by side, exporting (roadmap entry 3 adds JSON export to the library),
  document-based app features (saving, versions, iCloud), localisation (the
  UI is English), App Store distribution.

## Capabilities

### New Capabilities

- `inspector-app`: the SwiftyExif debug app: opening files, presenting
  everything the library extracts (summary, tags, tag details, directories,
  warnings, errors), searching, filtering and copying, on macOS, iOS and
  iPadOS.

### Modified Capabilities

None. The app only uses the existing `metadata-reading-api`; no library
behaviour changes.

## Impact

- New: `App/project.yml`, `App/SwiftyExif/` (app sources, assets,
  Info.plist and entitlements settings), `App/SwiftyExifTests/` (unit tests).
- `.gitignore` ignores the generated `App/SwiftyExif.xcodeproj`.
- `CLAUDE.md` and `README.md` gain the app build and test commands.
- Development dependency: XcodeGen (`brew install xcodegen`, 2.46 at the
  time of writing). It is not needed to build the library.
- Signing: automatic signing with team `4TNB35NY7G`, set in `project.yml`.
  macOS builds use the App Sandbox with read-only access to user-selected
  files.
