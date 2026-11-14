# Proposal

## Why

Every format on the roadmap stores its core metadata in TIFF structure: DNG,
CR2, NEF and ARW are TIFF files, and CR3 and RAF embed TIFF-structured EXIF
blocks. A correct, robust TIFF/EXIF reader is therefore the foundation for
all later work, including the Inspector app (roadmap entry 2), which needs
something to show. This change implements roadmap entry 1,
`add-tiff-exif-reading`.

## What Changes

- Create the Swift package with the library product `SwiftyExifTool` and a
  Swift Testing test target, for macOS 14, iOS 17 and iPadOS 17.
- Add a public reading API that accepts a file URL or in-memory data and
  returns all metadata found, plus warnings for recoverable problems. Files
  are read on demand, not loaded whole.
- Detect the file format from content. TIFF-structured files are read;
  other recognised formats (BigTIFF, JPEG, PNG, ISO BMFF containers such as
  CR3 and HEIF) are rejected with an error that names the detected format;
  anything else is rejected as unknown. Brand-level identification (CR3
  versus HEIF) and RAF follow in roadmap entries 5 and 6.
- Parse TIFF structure: both byte orders, IFD chains (IFD0, IFD1, …),
  SubIFDs, ExifIFD, GPS and InteropIFD pointers, all twelve TIFF field types,
  with bounds checks, cycle detection and resource limits.
- Define the standard tags of TIFF 6.0, Exif (CIPA DC-008) including the
  GPS and Interoperability IFDs, with exiftool-compatible names and groups.
  Each tag exposes its stored value losslessly, its value as `exiftool -n`
  reports it, and its display text as `exiftool` reports it by default.
- Report unknown tags with their numeric ID instead of dropping them.
- Add a fixture workflow: small synthetic TIFF fixtures committed to the
  repository, and exiftool output snapshots recorded from them, which serve
  as the provenance for names and conversions and as the expected results of
  the tests.

### Scope

- **Formats in scope:** classic TIFF (both byte orders). DNG, CR2, NEF and
  ARW files are TIFF-structured and are read through the same path, but are
  reported as file type TIFF until roadmap entry 4 adds format detection for
  them.
- **Groups in scope:** `File` (FileType, FileTypeExtension, MIMEType,
  ExifByteOrder), `IFD0`, `IFD1` and further chained IFDs, `SubIFD`,
  `SubIFD1`, …, `ExifIFD`, `GPS`, `InteropIFD`.
- **Explicitly out of scope:** decoding MakerNotes (the MakerNote tag is
  exposed as an undecoded block), DNG-specific tags and format detection for
  RAW formats (entry 4), XMP (entry 7; the XMP tag is exposed as an undecoded
  block), IPTC and ICC data, Composite tags, the `System` and `ExifTool`
  groups (filesystem information and exiftool's own tags), BigTIFF, JSON
  export (entry 3), writing (entry 8), and decoding image data.

## Capabilities

### New Capabilities

- `file-type-detection`: identify a file's format from its leading bytes and
  report supported versus recognised-but-unsupported formats.
- `tiff-container`: TIFF structure: byte order, IFD chains and sub-directory
  pointers, field types and value locations, bounds, cycle and resource
  safety, warnings for malformed structure.
- `exif-tags`: standard TIFF, Exif, GPS and Interop tag definitions, group
  assignment, value conversion and display conversion, unknown-tag naming.
- `metadata-reading-api`: the public reading entry points, inputs, the result
  model (tags, groups, values, directories, warnings), errors and
  concurrency guarantees.

### Modified Capabilities

None. No specs exist yet.

## Impact

- New files: `Package.swift`, `Sources/SwiftyExifTool/`,
  `Tests/SwiftyExifToolTests/` with committed synthetic fixtures and exiftool
  snapshots, and a development script that records snapshots with the
  locally installed exiftool (13.55 at the time of writing).
- New public API surface of the library; later changes extend it.
- `CLAUDE.md` gains the commands for regenerating fixtures and snapshots.
- No runtime dependencies; exiftool is needed only to regenerate snapshots,
  not to run the tests.
