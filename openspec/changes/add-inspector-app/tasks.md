# Tasks

## 1. Project setup

- [x] 1.1 Create `App/project.yml` per design D1 (local package `..`, multiplatform target `SwiftyExif`, bundle ID `info.stichling.SwiftyExif`, team `4TNB35NY7G`, macOS 14 / iOS 17, generated Info.plist and macOS sandbox entitlements with read-only user-selected files, hosted test target `SwiftyExifTests` with the library fixtures as a folder reference), a minimal `SwiftyExifApp` showing an empty window, and ignore `App/SwiftyExif.xcodeproj` in `.gitignore`; verify `xcodegen generate --spec App/project.yml` succeeds and `git status` does not list the generated project.
- [x] 1.2 Verify the empty app builds with `xcodebuild … -destination 'platform=macOS' build` and `… -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build`, and that both bundles report the name SwiftyExif and bundle ID `info.stichling.SwiftyExif` (`plutil -p` on the built Info.plist).
- [x] 1.3 Add the build and test commands of design D6 to `CLAUDE.md` and `README.md`; verify they run as written.

## 2. Presentation model

- [x] 2.1 Implement `TagRow` and `InspectedFile` (summary values, rows per tag) per design D2; verify with unit tests on `basic-le`: Orientation row texts (`0x0112`, SHORT, 1, `6`, `Rotate 90 CW`, offset), File group rows without ID/type/count/offset, and the summary values (file type, byte order, tag, directory and warning counts).
- [x] 2.2 Implement `TagQuery` (group sections in first-occurrence order, search over name, hex ID, value and display text, group selection, hide-unknown); verify with unit tests for the search scenarios (`rotate`, `0x829a`), hiding empty groups while searching, and the hide-unknown scenario on `unknown-tags`.
- [x] 2.3 Implement `CopyText` and the `Pasteboard` abstraction; verify with unit tests for value, display text and the row format `IFD0:Orientation<TAB>6<TAB>Rotate 90 CW` using a test pasteboard.
- [x] 2.4 Implement `InspectorModel` with the loading states, generation counter, security-scoped access and injectable reader per design D3; verify with unit tests: success on a fixture, `.failed` with `unsupportedFormat(.png)` for `sig-png`, a superseded slow read whose result is discarded, and file contents and modification date unchanged after opening.

## 3. Views

- [x] 3.1 Build the main window: `NavigationSplitView` with sidebar entries Summary, All tags, one entry per group with counts, Directories and Warnings; empty state with an Open button; progress view while loading; error view for each `ReadError` case per design D5; verify by opening `basic-le`, `bad-exif-pointer` and `sig-png` in the macOS app (app check).
- [x] 3.2 Build the tag views: `Table` with all spec columns on macOS and regular-width iPadOS, two-line `List` rows in compact width, unknown tags visibly marked, and the details inspector with stored value, value, display text, offsets and the not-loaded state; verify with `basic-le` (ExposureTime details), `unknown-tags` and `large-undefined` on macOS and on the iPhone and iPad simulators (app check).
- [x] 3.3 Build the Directories and Warnings views, `.searchable`, the filter menu and the copy context menu plus Cmd-C on macOS; verify search, filters and copying against the spec scenarios in the macOS app (app check).

## 4. Opening files

- [x] 4.1 Add the file picker (`.fileImporter`, any content type) with cancel keeping the current file; verify on macOS and the iOS simulator by picking a fixture and cancelling a second picker (app check).
- [x] 4.2 Add drag and drop for macOS (`URL`) and iPadOS (`Transferable` file representation, display of the suggested name); verify by dropping a fixture on the macOS window (empty and onto the tag table of a shown file) and on an iPad (empty window, and onto the title area while a file is shown; drops onto the tag list are not delivered by iPadOS, see design D4) (app check).
- [x] 4.3 Add the document types (`LSHandlerRank = Alternate` for `public.tiff`, `public.camera-raw-image`, `com.adobe.raw-image`), `LSSupportsOpeningDocumentsInPlace`, `.onOpenURL` and `.handlesExternalEvents`; verify with `open -a SwiftyExif <NEF file>` and Finder's "Open With" on macOS that one window shows the file and that SwiftyExif is not made the default app (app check).

## 5. Integration

- [x] 5.1 Run the app unit tests on macOS and the iOS simulator with the commands of design D6 and the library tests with `swift test`; verify all pass.
- [x] 5.2 Open the four sample RAWs from the `add-tiff-exif-reading` check (NEF, ARW, CR2, DNG, downloaded again from raw.pixls.us, not committed) on macOS; verify the interface stays responsive, the tag counts match `MetadataReader`, and opening a second file during loading shows only the second (app check).

## Workflow follow-up

- Archive the change with `/opsx:archive` after review, which also sets roadmap entry 2 to `done` in `docs/roadmap.md`.
