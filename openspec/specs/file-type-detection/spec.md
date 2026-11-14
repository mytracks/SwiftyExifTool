# file-type-detection Specification

## Purpose

Identifies a file's format from its content rather than its name, so the
library picks the right reader and rejects files it cannot read with a clear,
specific error.

## Requirements

### Requirement: Detection by content

The library SHALL determine the file format from the file's leading bytes. The file name and extension SHALL NOT influence detection.

#### Scenario: TIFF with a misleading extension
- **WHEN** a little-endian TIFF file (bytes `49 49 2A 00`) named `photo.jpg` is read
- **THEN** it is detected as TIFF and its metadata is returned

#### Scenario: JPEG with a TIFF extension
- **WHEN** a file starting with `FF D8 FF` named `image.tif` is read
- **THEN** reading fails with an unsupported-format error naming JPEG

### Requirement: TIFF signature

The library SHALL detect TIFF when the file starts with `49 49 2A 00` (little-endian) or `4D 4D 00 2A` (big-endian), per TIFF 6.0 section 2 ("Image File Header").

#### Scenario: Little-endian TIFF
- **WHEN** a file starts with `49 49 2A 00`
- **THEN** it is detected as TIFF with little-endian byte order

#### Scenario: Big-endian TIFF
- **WHEN** a file starts with `4D 4D 00 2A`
- **THEN** it is detected as TIFF with big-endian byte order

### Requirement: Recognised but unsupported formats

The library SHALL recognise BigTIFF (TIFF header with version 43, per the BigTIFF specification), JPEG (`FF D8 FF`, ITU-T T.81), PNG (`89 50 4E 47 0D 0A 1A 0A`, PNG specification) and ISO BMFF (`ftyp` at bytes 4–7, ISO/IEC 14496-12) and reject them with an unsupported-format error that names the format. For ISO BMFF the error SHALL include the major brand.

#### Scenario: BigTIFF
- **WHEN** a file starts with `49 49 2B 00`
- **THEN** reading fails with an unsupported-format error naming BigTIFF

#### Scenario: PNG
- **WHEN** a file starts with `89 50 4E 47 0D 0A 1A 0A`
- **THEN** reading fails with an unsupported-format error naming PNG

#### Scenario: ISO BMFF with its brand
- **WHEN** a file has the bytes `ftyp` at offset 4 followed by the major brand `abcd`
- **THEN** reading fails with an unsupported-format error naming ISO BMFF and the brand `abcd`

### Requirement: Unknown formats

The library SHALL reject a file whose leading bytes match no known signature, including empty files and files shorter than any signature, with an unknown-format error.

#### Scenario: Text file
- **WHEN** a file containing the ASCII text `hello world` is read
- **THEN** reading fails with an unknown-format error

#### Scenario: Empty file
- **WHEN** a zero-byte file is read
- **THEN** reading fails with an unknown-format error

### Requirement: File group tags

For a detected TIFF file the result SHALL contain the `File` group tags FileType, FileTypeExtension, MIMEType and ExifByteOrder, with values and display texts matching exiftool's output for the same file (observed with exiftool 13.55).

#### Scenario: Big-endian TIFF file tags
- **WHEN** a valid big-endian TIFF fixture is read
- **THEN** FileType is `TIFF`, MIMEType is `image/tiff`, FileTypeExtension has value `TIF` and display text `tif`, and ExifByteOrder has value `MM` and display text `Big-endian (Motorola, MM)`

#### Scenario: Little-endian TIFF byte order
- **WHEN** a valid little-endian TIFF fixture is read
- **THEN** ExifByteOrder has value `II` and the display text recorded in that fixture's exiftool snapshot
