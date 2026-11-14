# SwiftyExifTool

A Swift package for reading and writing image metadata, with a focus on camera
RAW files, for macOS, iOS and iPadOS. It reimplements the parts of
[ExifTool](https://exiftool.org) that this goal needs, as a clean-room
implementation under the MIT licence.

The repository will also contain the **Inspector** (roadmap entry 2), a
SwiftUI app for macOS, iOS and iPadOS that shows everything the library
extracts from a file. It is meant as a debugging aid.

> **Status:** early development. Reading TIFF-structured metadata (TIFF 6.0,
> Exif 3.1, GPS, Interoperability) works, including TIFF-based RAW files
> (DNG, CR2, NEF, ARW), which are still reported as file type TIFF. RAW
> format detection, MakerNotes, XMP and writing follow; see
> [docs/roadmap.md](docs/roadmap.md).

## Usage

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/<owner>/SwiftyExifTool.git", branch: "main"),
```

Read a file:

```swift
import SwiftyExifTool

func printMetadata(of url: URL) throws {
    let metadata = try MetadataReader.read(contentsOf: url)
    for tag in metadata.tags {
        print("\(tag.group):\(tag.name) = \(tag.displayText)")
    }
    if let exposure = metadata.tag(.exifIFD, "ExposureTime") {
        print(exposure.value)        // 0.004   (as `exiftool -n`)
        print(exposure.displayText)  // 1/250   (as `exiftool`)
    }
    for warning in metadata.warnings {
        print("warning:", warning)
    }
}
```

Each tag carries its stored value (lossless), its value as `exiftool -n`
prints it, and its display text as `exiftool` prints it. On iOS and iPadOS,
call `startAccessingSecurityScopedResource()` on document-picker URLs before
reading.

## Planned scope

- **Reading:** TIFF, DNG, Canon CR2/CR3, Nikon NEF, Sony ARW, Fujifilm RAF:
  EXIF, TIFF, GPS, DNG tags, XMP (embedded and sidecar), and vendor
  MakerNotes.
- **Writing:** EXIF, TIFF and GPS tags in the file, embedded XMP, and XMP
  sidecar files. Image data and MakerNotes are never altered.
- **Compatibility:** tag names, groups and values follow the output of
  `exiftool -j -a -G1`.

## Requirements

- macOS 14, iOS 17 or iPadOS 17 or later
- Xcode 27 / Swift 6.4
- No third-party dependencies

## Development

Work is planned and tracked with [OpenSpec](https://github.com/Fission-AI/OpenSpec):

- `openspec/config.yaml`: project constraints for all changes
- `openspec/specs/`: the current behaviour contract, grown by archived changes
- `openspec/changes/`: changes in progress
- [docs/roadmap.md](docs/roadmap.md): planned changes and the capability map
- [docs/clean-room.md](docs/clean-room.md): which sources may be used, which
  may not, and how provenance is recorded

For conformance testing, install exiftool as a development tool
(`brew install exiftool`). It is never a runtime dependency.

### SwiftyExif app

The debug app lives in `App/`. Its Xcode project is generated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not committed:

```sh
brew install xcodegen
xcodegen generate --spec App/project.yml
open App/SwiftyExif.xcodeproj
```

From the command line:

```sh
xcodebuild -project App/SwiftyExif.xcodeproj -scheme SwiftyExif -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= test
xcodebuild -project App/SwiftyExif.xcodeproj -scheme SwiftyExif -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

## Licence

MIT, see [LICENSE](LICENSE). SwiftyExifTool contains no code or tag tables
from ExifTool or other GPL/LGPL projects; see
[docs/clean-room.md](docs/clean-room.md).
