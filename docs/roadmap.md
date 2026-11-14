# Roadmap

This roadmap orders the OpenSpec changes that build SwiftyExifTool. Each entry
is a candidate change: its name, goal, the capabilities it introduces or
modifies, and the questions its proposal or design has to settle. The order
of entries 1–3 is fixed; later entries may be reordered as needs arise.

Status values: `planned`, `in progress`, `done`.

## Scope

**In scope**

- Reading metadata from TIFF, DNG, Canon CR2 and CR3, Nikon NEF, Sony ARW and
  Fujifilm RAF.
- Metadata groups: TIFF IFDs (IFD0, IFD1, SubIFDs), ExifIFD, GPS, InteropIFD,
  DNG tags, embedded XMP, XMP sidecars, and vendor MakerNotes (Canon, Nikon,
  Sony, Fujifilm).
- Listing embedded previews and thumbnails (location and size, no decoding).
- Writing EXIF, TIFF and GPS tags in the file; writing embedded XMP; writing
  XMP sidecar files.
- The Inspector app: a debug aid that shows everything the library extracts
  from a selected file on macOS, iOS and iPadOS.

**Out of scope until a change adds it**

- Writing MakerNotes (they are preserved byte-exactly, never edited).
- IPTC-IIM, ICC profiles, Photoshop IRB.
- Non-RAW formats (JPEG, HEIF, PNG, video, PDF, …), except where a RAW
  container embeds them (e.g. the JPEG inside RAF).
- ExifTool Composite tags (e.g. ImageSize, LensID).
- Decoding image data, geotagging, file renaming, copying tags between files,
  and ExifTool's command-line interface.

## Capability map

Capability paths are proposals. A change may refine a path, but must then
update this table.

| Capability | Covers | Introduced by |
|---|---|---|
| `file-type-detection` | Identify a file's format from its content, not its extension | 1 |
| `tiff-container` | TIFF structure: byte order, IFD chains, SubIFD/Exif/GPS/Interop pointers, field types, bounds and loop safety | 1 |
| `exif-tags` | Standard TIFF, Exif, GPS and Interop tag definitions with raw and converted values | 1 |
| `metadata-reading-api` | Public reading API: inputs, result model (tag, group, raw value, converted value), warnings and errors | 1 |
| `inspector-app` | The debug GUI app | 2 |
| `exiftool-conformance` | Development tooling: exiftool-shaped output, comparison with exiftool snapshots, the fixture gate, the sample corpus with its report and baseline | 3 |
| `formats/dng` | DNG detection and DNG-specific tags | 4 |
| `formats/canon-cr2` | CR2 detection and container specifics | 4 |
| `formats/nikon-nef` | NEF detection and container specifics | 4 |
| `formats/sony-arw` | ARW detection and container specifics | 4 |
| `isobmff-container` | ISO BMFF box structure as used by CR3 | 5 |
| `formats/canon-cr3` | CR3 detection and the Canon metadata boxes | 5 |
| `formats/fujifilm-raf` | RAF header, directory and embedded JPEG/EXIF | 6 |
| `xmp-metadata` | Parsing and serialising XMP packets, namespaces and groups | 7 |
| `xmp-sidecar` | Locating, reading and writing `.xmp` sidecar files | 7 |
| `metadata-writing` | Writing tags in the file: API, validation, preservation and atomicity guarantees | 8 |
| `makernotes/canon` | Canon MakerNote decoding (read-only) | 11 |
| `makernotes/nikon` | Nikon MakerNote decoding (read-only) | 12 |
| `makernotes/sony` | Sony MakerNote decoding (read-only) | 13 |
| `makernotes/fujifilm` | Fujifilm MakerNote decoding (read-only) | 14 |

## Changes

### 1. `add-tiff-exif-reading` — done

Lay the foundation: the Swift package and reading of TIFF-structured
metadata, which DNG, CR2, NEF and ARW, and the EXIF blocks inside CR3 and
RAF, all reuse.

- Package scaffold: library product `SwiftyExifTool`, tests with Swift
  Testing, platforms per `openspec/config.yaml`.
- Input from a file URL and from in-memory data, without loading whole files.
- Content-based detection of TIFF; other formats are recognised as
  unsupported rather than misparsed.
- TIFF parsing: both byte orders, IFD chains, Exif/GPS/Interop/SubIFD
  pointers, all TIFF field types, bounds checks, cycle detection.
- Standard tags from TIFF 6.0 and CIPA DC-008 (Exif) with raw and converted
  values; unknown tags are still reported, with their numeric ID.
- Small synthetic fixtures built by the tests.
- Capabilities: `file-type-detection`, `tiff-container`, `exif-tags`,
  `metadata-reading-api`.
- To settle: the shape of the public result model (typed values versus
  ExifTool-style strings); the format for provenance records; how warnings
  are surfaced.

### 2. `add-inspector-app` — done

A multiplatform SwiftUI app that serves as the debug aid for all later work.

- Open a file via the file picker, drag and drop, and "Open With" on macOS.
- Show every extracted tag grouped by its group: name, tag ID (hex), field
  type, count, raw value, converted value, and byte offset where known.
- Show warnings and errors; search and filter; copy values.
- Capabilities: `inspector-app`.
- To settle: how the Xcode project is created and maintained (hand-made in
  Xcode or generated, e.g. with XcodeGen); app name and bundle identifier;
  signing team.

### 3. `add-exiftool-conformance` — in progress

Measure parity with exiftool before adding formats. The output is a
development instrument, not a library feature: the library's public API
does not change.

- exiftool-shaped output of reading results, like `exiftool -j -a -G1 -u
  [-n]`, in the development target `ConformanceKit` and printed by
  `swift run fixtures json`.
- A fixture corpus: synthetic files in the repository; sample RAW files kept
  outside git and described by a manifest (source, licence, checksum).
- A comparison runner that diffs our output with exiftool's: synthetic
  fixtures are a strict gate with documented, deliberate deviations; real
  files produce a report and a committed baseline of per-tag status.
- Capabilities: `exiftool-conformance` (development tooling). The earlier
  idea of a library capability `metadata-json-export` was dropped.
- Settled: expected exiftool output is stored as committed snapshots, so
  tests run without exiftool; personal fields in corpus snapshots are
  stored as hashes. The corpus lives in the git-ignored `Corpus/` directory
  (or `SWIFTYEXIF_CORPUS`) and is downloaded with
  `swift run fixtures corpus fetch` (CC0 samples from raw.pixls.us).

### 4. `add-tiff-based-raw-formats` — planned

DNG, CR2, NEF and ARW on top of the TIFF core.

- Detection and container specifics (CR2 header, NEF and ARW SubIFD layouts).
- DNG tags from the DNG specification.
- The MakerNote is located and exposed as an undecoded block (offset,
  length); embedded previews are listed.
- Capabilities: `formats/dng`, `formats/canon-cr2`, `formats/nikon-nef`,
  `formats/sony-arw`; modifies `file-type-detection`.
- Known gaps from real files (see `add-tiff-exif-reading` notes): DNG and
  TIFF/EP tags, Compression 7/32767/34713 and PhotometricInterpretation
  32803, format-dependent names for IFD0 previews, derived preview tags.
  The DNG specification is available as a source.

### 5. `add-canon-cr3-container` — planned

- ISO BMFF box parsing; Canon metadata boxes carrying TIFF-structured IFD0,
  Exif, MakerNote and GPS data; the XMP box.
- Capabilities: `isobmff-container`, `formats/canon-cr3`; modifies
  `file-type-detection`.

### 6. `add-fujifilm-raf-container` — planned

- RAF header and directory; EXIF from the embedded JPEG (APP1 only, no JPEG
  decoding).
- Capabilities: `formats/fujifilm-raf`; modifies `file-type-detection`.

### 7. `add-xmp-reading` — planned

- Embedded XMP in TIFF-based files (tag 0x02BC), CR3 and RAF, and `.xmp`
  sidecars next to the file.
- XMP groups per namespace (e.g. `XMP-dc`, `XMP-xmp`, `XMP-exif`).
- Capabilities: `xmp-metadata`, `xmp-sidecar`.

### 8. `add-exif-writing` — planned

- Set and delete EXIF, TIFF and GPS tags in TIFF, DNG, CR2, NEF and ARW.
- Value validation against tag definitions; image data and MakerNotes
  preserved byte-exactly; atomic replacement; refusal when the file could not
  be fully parsed.
- Verified by re-reading with our reader and by `exiftool -validate`.
- Capabilities: `metadata-writing`.
- To settle: strategy when a value no longer fits in place (relocation of
  IFDs and data) and how MakerNote offsets stay valid.

### 9. `add-xmp-writing` — planned

- Create and update embedded XMP in TIFF-based files; create and update
  sidecars, preserving unknown properties.
- Capabilities: modifies `xmp-metadata`, `xmp-sidecar`, `metadata-writing`.

### 10. `add-cr3-raf-writing` — planned

- Extend in-file writing (EXIF and XMP) to CR3 and RAF.
- Capabilities: modifies `formats/canon-cr3`, `formats/fujifilm-raf`,
  `metadata-writing`.

### 11–14. Vendor MakerNotes — planned

`add-canon-makernotes`, `add-nikon-makernotes`, `add-sony-makernotes`,
`add-fujifilm-makernotes`: read-only decoding of each vendor's MakerNote.

- The most effort under the clean-room policy: definitions come from
  black-box observation of exiftool output on fixtures and from independent
  documentation, each with recorded provenance.
- Encrypted sections (Nikon, Sony) may be deferred to follow-up changes.
- These changes may be interleaved with 8–10 depending on need.
- Capabilities: `makernotes/canon`, `makernotes/nikon`, `makernotes/sony`,
  `makernotes/fujifilm`.

## Later candidates

Not planned yet; each needs its own decision.

- Composite tags (ImageSize, Megapixels, LensID, …).
- JPEG and HEIF reading.
- A command-line tool.
- IPTC-IIM reading.
