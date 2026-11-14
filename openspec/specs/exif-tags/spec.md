# exif-tags Specification

## Purpose

Defines the standard TIFF, Exif, GPS and Interoperability tags: how each one
is named and grouped, and how its stored value is converted into the value
and display text that exiftool reports, so results are interchangeable with
exiftool's.

## Requirements

### Requirement: Standard tag coverage

The library SHALL define every tag of TIFF 6.0 (baseline and extension fields) and every tag of the 0th IFD, Exif IFD, GPS IFD and Interoperability IFD in CIPA DC-008-2026 (Exif 3.1). Each definition SHALL record its source document and section.

#### Scenario: Tags from both specifications
- **WHEN** a fixture contains Make (0x010F, TIFF 6.0) and DateTimeOriginal (0x9003, Exif)
- **THEN** both are reported under their defined names, not as unknown tags

#### Scenario: Provenance is complete
- **WHEN** the tag definition tests run
- **THEN** every defined tag has a source document and section recorded

### Requirement: Tag tables per directory

The library SHALL look up tags of the GPS directory in the GPS tag table, and tags of every other directory (IFD0, IFD1, …, SubIFDs, ExifIFD, InteropIFD) in one shared table, so a tag stored in an unusual directory keeps its name and is reported in the group of the directory it was found in (observed with exiftool 13.55).

#### Scenario: Interop tags
- **WHEN** InteropIFD contains 0x0001 with `R98`
- **THEN** it is reported as InteropIFD:InteropIndex with value `R98` and display text `R98 - DCF basic file (sRGB)`

#### Scenario: Exif tag in IFD0
- **WHEN** ExposureTime (0x829A) is stored in IFD0 instead of ExifIFD
- **THEN** it is reported as IFD0:ExposureTime

#### Scenario: Same ID in GPS and main table
- **WHEN** GPS contains 0x0001 with `N` and InteropIFD contains 0x0001 with `R98`
- **THEN** they are reported as GPS:GPSLatitudeRef and InteropIFD:InteropIndex

### Requirement: exiftool-compatible names

Tag names SHALL match the names exiftool 13.55 reports for the same tag ID, as observed on fixtures, even where the specification uses a different name. The observation SHALL be recorded as provenance.

#### Scenario: Names that differ from the specification
- **WHEN** a fixture contains 0x0101 (TIFF 6.0: ImageLength) and 0x8827 (Exif: PhotographicSensitivity)
- **THEN** they are reported as ImageHeight and ISO

### Requirement: Three value levels

Each tag SHALL expose its stored value losslessly (field type, count, decoded numbers, strings or bytes), its value as reported by `exiftool -n`, and its display text as reported by `exiftool` without `-n`.

#### Scenario: Rational exposure time
- **WHEN** ExposureTime is stored as RATIONAL 1/250
- **THEN** the stored value is the rational 1/250, the value is 0.004, and the display text is `1/250`

#### Scenario: Enumerated orientation
- **WHEN** Orientation is stored as SHORT 6
- **THEN** the value is 6 and the display text is `Rotate 90 CW`

#### Scenario: Byte array
- **WHEN** GPSVersionID is stored as BYTE[4] 2, 3, 0, 0
- **THEN** the value is `2 3 0 0` and the display text is `2.3.0.0`

### Requirement: Conversions match observations

For every defined tag that exiftool 13.55 shows in its JSON output, the value and display text SHALL equal exiftool's output for the committed fixtures that contain the tag. Every enumerated or bit-field tag SHALL be covered by fixtures for each value its specification defines.

#### Scenario: Flash bit field
- **WHEN** Flash is stored as SHORT 16
- **THEN** the value is 16 and the display text is `Off, Did not fire`

#### Scenario: Resolution unit and GPS reference
- **WHEN** ResolutionUnit is 2 and GPSLatitudeRef is `N`
- **THEN** the display texts are `inches` and `North`

#### Scenario: Fixture snapshot comparison
- **WHEN** the conformance tests compare all committed fixtures with their recorded exiftool snapshots
- **THEN** every tag exiftool reports matches in group, name, value and display text, except documented deviations

### Requirement: Values outside the definition

A value that a tag's enumeration does not define SHALL keep its numeric value and have the display text `Unknown (<value>)` (observed with exiftool 13.55).

#### Scenario: Undefined orientation
- **WHEN** Orientation is stored as SHORT 99
- **THEN** the value is 99 and the display text is `Unknown (99)`

### Requirement: Strings

ASCII and UTF-8 values SHALL be returned without trailing NUL bytes. Trailing spaces SHALL be removed only for the tags where exiftool 13.55 removes them, as observed per tag on fixtures. ASCII values that are not valid UTF-8 SHALL be decoded as ISO 8859-1. This deliberately differs from exiftool 13.55, whose JSON output replaces such bytes with `?`.

#### Scenario: Padded Make
- **WHEN** Make is stored as `Cam` followed by two spaces and three NULs
- **THEN** the value is `Cam`

#### Scenario: Spaces kept in ImageDescription
- **WHEN** ImageDescription is stored as eight spaces followed by a NUL
- **THEN** the value is the eight spaces

#### Scenario: Non-UTF-8 bytes
- **WHEN** Artist is stored as the bytes `4D FC 6C 6C 65 72 00`
- **THEN** the value is `Müller` and the snapshot comparison records this as a documented deviation

### Requirement: Unknown tags

A tag ID without a definition SHALL still be reported, flagged as unknown, with the name `Exif_0x<id>` in the shared table and `GPS_0x<id>` in the GPS table, using four lowercase hex digits (observed with `exiftool -u`, 13.55). Its value is the stored value; its display text need not match exiftool.

#### Scenario: Unknown IFD0 tag
- **WHEN** IFD0 contains tag 0xC0DE as SHORT 7
- **THEN** a tag IFD0:Exif_0xc0de with value 7 is reported and flagged as unknown

#### Scenario: Unknown GPS tag
- **WHEN** GPS contains tag 0x0077 as SHORT 9
- **THEN** a tag GPS:GPS_0x0077 with value 9 is reported and flagged as unknown

### Requirement: Embedded blocks stay undecoded

The XMP packet (0x02BC) and IPTC (0x83BB) tags (XMP Specification Part 3, Table 12), MakerNote (0x927C) and ICC profile (0x8773, ICC Technical Note "Embedding ICC profiles") SHALL be reported as undecoded binary tags with their offset and length, named as `exiftool -v2` names them on the fixtures. Their content is decoded by later changes. exiftool hides these tags in its JSON output, so they are excluded from the snapshot comparison.

#### Scenario: MakerNote block
- **WHEN** ExifIFD contains a 64-byte MakerNote
- **THEN** a binary tag in ExifIFD reports tag ID 0x927C, value offset and length 64, and no MakerNote content is decoded

#### Scenario: XMP block
- **WHEN** IFD0 contains a 40-byte tag 0x02BC
- **THEN** it is reported as IFD0:ApplicationNotes, an undecoded binary tag of length 40
