# Design

## Context

The library exposes `MetadataReader.read(contentsOf:)`, which returns a
`Sendable` `Metadata` value (tags in traversal order, directories, warnings)
or a typed `ReadError`. It reads files through a FileHandle with bounded,
on-demand reads and never loads a whole RAW file. See proposal.md for the
motivation and the specs for the required behaviour. Nothing in the
repository builds an app yet; this change adds the first Xcode project.

Constraints: macOS 14 / iOS 17, Swift 6 strict concurrency, no third-party
runtime dependencies, sandboxed file access on all platforms, and XcodeGen
(2.46) as the agreed way to maintain the project.

## Goals / Non-Goals

**Goals:**
- One SwiftUI code base for macOS, iPadOS and iOS, with platform differences
  limited to layout and pasteboard.
- Presentation logic (rows, grouping, search, filters, copy text, loading
  state) testable without UI, with the library's committed fixtures.
- A project that agents and humans regenerate and build from the command line.

**Non-Goals:**
- UI tests that drive the picker, drag and drop or Finder; these are checked
  by hand (see tasks).
- An app icon or visual design beyond system styling.
- Any library change; if the app needs something the API lacks, that is a
  separate change.

## Decisions

### D1. XcodeGen project under `App/`

```
App/
  project.yml                 committed; the only source of the project
  SwiftyExif/                 app sources and Assets.xcassets
  SwiftyExifTests/            unit tests (Swift Testing)
  SwiftyExif.xcodeproj        generated, git-ignored
```

`project.yml` declares the local package (`path: ..`), one application
target `SwiftyExif` with `supportedDestinations: [iOS, macOS]` (iPad
through `TARGETED_DEVICE_FAMILY = 1,2`), deployment targets macOS 14 / iOS
17, bundle identifier `info.stichling.SwiftyExif`, automatic signing with
`DEVELOPMENT_TEAM = 4TNB35NY7G`, and a hosted unit-test target
`SwiftyExifTests`. The Info.plist and entitlements are generated from
`project.yml` (`info:` and `entitlements:` properties), so there is no
hand-edited plist to drift.

*Alternatives:* a hand-made project (rejected by the maintainer: merge
conflicts, unreviewable diffs); Tuist (more powerful, but a Swift DSL and a
heavier tool for one target); committing the generated project (rejected:
generated files in review and drift between `project.yml` and the project).

### D2. Presentation model separated from views

- `InspectorModel` (`@Observable`, `@MainActor`) owns the state:
  `.empty`, `.loading(URL)`, `.loaded(InspectedFile)`, `.failed(URL, ReadError)`.
- `InspectedFile` holds the file name, size, the `Metadata`, and precomputed
  `TagRow`s.
- `TagRow` is a value type with the texts the table shows (ID as `0x%04X`,
  field type name, count, value, display text, value offset) and keeps the
  `Tag` for the details view.
- `TagQuery` (search text, selected groups, hide-unknown) is a pure function
  from rows to `[GroupSection]`, preserving first-occurrence order of groups
  and traversal order of rows.
- `CopyText` builds the strings for copying; a small `Pasteboard` protocol
  wraps `NSPasteboard` / `UIPasteboard`.

Views only render these values, so every spec scenario except the
platform-integration ones is a unit test.

### D3. Reading off the main actor

`open(url)` increments a generation counter, sets `.loading`, and starts a
task that calls a reader closure in a detached task (default:
`MetadataReader.read(contentsOf:)`), wrapped in
`startAccessingSecurityScopedResource()` / `stop…()`. When it finishes, the
result is applied only if its generation is still current, which implements
"opening another file supersedes a read in progress" without relying on
cancellation inside the synchronous library call. The closure is injectable
so tests can use slow or failing readers.

File size comes from `URLResourceValues.fileSize` within the same scoped
access. The app keeps only the `Metadata` value; large values stay unloaded
(`StoredValue.Contents.notLoaded`), so memory does not grow with RAW file
size. Bounds checking and memory limits are the library's (see the
`tiff-container` spec); the app adds no parsing of its own.

### D4. Opening files

- **Picker:** `.fileImporter(allowedContentTypes: [.item])`. Any file is
  allowed because the library detects formats by content
  (`file-type-detection`); unsupported files produce the error view.
- **Drag and drop:** `.dropDestination(for: URL.self)` on macOS; on iPadOS
  drops from Files arrive as file representations, so a `Transferable`
  `FileRepresentation` imports them as a temporary copy that the system
  provides inside the sandbox. The user's file is not modified.
- **Open With (macOS):** `CFBundleDocumentTypes` with `LSHandlerRank =
  Alternate` for `public.tiff`, `public.camera-raw-image` and
  `com.adobe.raw-image`, and `.onOpenURL` on the window. The same
  declaration plus `LSSupportsOpeningDocumentsInPlace` makes "Open in
  SwiftyExif" available on iOS as a side effect; it is not a requirement.
- `.handlesExternalEvents(matching: ["*"])` keeps one window on macOS
  instead of opening a new one per file.

*Alternative:* `DocumentGroup` with a read-only `FileDocument`. Rejected: it
loads the whole file into memory as `Data` (`FileWrapper`), which defeats
bounded reading for 50 MB RAW files, and it adds document UI (new, save,
versions) that a viewer does not need.

### D5. Layout

- `NavigationSplitView`: the sidebar lists Summary, each tag group (with
  counts), Directories and Warnings; the detail column shows the selection.
- Tag groups: a `Table` with the columns of the spec on macOS and in regular
  width on iPadOS; a `List` with two-line rows (name and display text, then
  ID, type and value) in compact width on iPhone.
- Tag details: `.inspector(isPresented:)` (macOS 14 / iOS 17).
- Search: `.searchable` on the detail column; filters in a toolbar menu.
- Copy: context menu on rows (value, display text, row) and Cmd-C for the
  selected row on macOS.
- An "All tags" sidebar entry shows every group as sections, which is what
  search and filters apply to.

### D6. Build and test commands

```
xcodegen generate --spec App/project.yml
xcodebuild -project App/SwiftyExif.xcodeproj -scheme SwiftyExif -destination 'platform=macOS' build test
xcodebuild -project App/SwiftyExif.xcodeproj -scheme SwiftyExif -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build test
```

The unit tests use the library's committed fixtures
(`Tests/SwiftyExifToolTests/Fixtures/synthetic`), added to the test target
as a folder reference, so no fixture is duplicated.

## Sources

No tag or format knowledge is added. Uniform type identifiers for the
document types (`public.tiff`, `public.camera-raw-image`,
`com.adobe.raw-image`) come from Apple's UniformTypeIdentifiers
documentation.

## Risks / Trade-offs

- [`.onOpenURL` delivery for Finder "Open With" differs between macOS
  versions and may open a second window] → `handlesExternalEvents`, plus a
  manual check on macOS 14 and the current macOS.
- [Drops on iPadOS deliver copies, so the summary shows the copy's name] →
  use the suggested file name of the item representation for display.
- [A synchronous library read cannot be cancelled] → superseded reads finish
  in the background and are discarded; reads are bounded, so the cost is
  small.
- [Tables with thousands of rows (later MakerNotes) may be slow on iPhone] →
  rows are precomputed once per file; revisit with real MakerNote data.
- [Signing team hard-coded in `project.yml`] → team IDs are not secret;
  contributors override it with `DEVELOPMENT_TEAM=… xcodebuild`.
