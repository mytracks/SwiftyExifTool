# tiff-container Specification

## Purpose

Reads the TIFF structure that TIFF files and all TIFF-based RAW formats share:
byte order, image file directories, sub-directory pointers and field values,
safely and predictably even for malformed or hostile files.

## Requirements

### Requirement: Image file header

The library SHALL read the 8-byte TIFF header (byte order, the value 42, offset of IFD0) per TIFF 6.0 section 2 and apply the byte order to every multi-byte value in the file.

#### Scenario: Big-endian values
- **WHEN** a big-endian TIFF fixture stores ImageWidth 640 as a SHORT in IFD0
- **THEN** ImageWidth has value 640

#### Scenario: Same content in both byte orders
- **WHEN** the little-endian and big-endian variants of the same synthetic fixture are read
- **THEN** both results contain the same tags with the same values, apart from ExifByteOrder

### Requirement: Directory entries and field types

The library SHALL read each IFD as a 2-byte entry count, 12-byte entries and a 4-byte next-IFD offset, and decode the twelve field types of TIFF 6.0 section 2 plus UTF-8 (type 129, CIPA DC-008-2026). Values of up to 4 bytes SHALL be read from the entry itself, larger values from the stored offset.

#### Scenario: Inline and offset values
- **WHEN** IFD0 contains a SHORT with count 1 and an ASCII string of 8 bytes
- **THEN** the SHORT is read from the entry and the string from its offset, and both values are correct

#### Scenario: Every field type
- **WHEN** a fixture contains one entry of each of the twelve TIFF field types, with counts 1 and 3
- **THEN** each value is decoded with the correct type, sign and count

#### Scenario: UTF-8 string
- **WHEN** an entry of type 129 holds the UTF-8 bytes of `Zürich` followed by a NUL
- **THEN** the value is the string `Zürich`

### Requirement: Unknown field types

The library SHALL skip an entry whose field type is not one of the defined types, add a warning naming the tag ID and type, and continue with the next entry, per the TIFF 6.0 rule that readers ignore unknown field types.

#### Scenario: Field type 99
- **WHEN** IFD0 contains an entry with field type 99 between two valid entries
- **THEN** both valid entries are returned and a warning names the skipped entry

### Requirement: IFD chain

The library SHALL follow the next-IFD offsets from IFD0 and assign the groups `IFD0`, `IFD1`, `IFD2`, … in chain order. A next-IFD offset of 0 ends the chain.

#### Scenario: Three chained IFDs
- **WHEN** IFD0 links to IFD1 and IFD1 links to IFD2
- **THEN** their tags are reported in the groups `IFD0`, `IFD1` and `IFD2` (observed with exiftool 13.55)

### Requirement: Sub-directories

The library SHALL follow the ExifIFD pointer (0x8769, Exif), the GPS pointer (0x8825, Exif) and the Interoperability pointer (0xA005, Exif) and the SubIFDs tag (0x014A, Adobe TIFF Technical Note 1 "TIFF Trees"), and assign the groups `ExifIFD`, `GPS`, `InteropIFD`, and `SubIFD`, `SubIFD1`, … in array order (observed with exiftool 13.55).

#### Scenario: Two SubIFDs
- **WHEN** IFD0 has a SubIFDs tag with two offsets
- **THEN** the tags of the first directory are in group `SubIFD` and those of the second in `SubIFD1`

#### Scenario: Interop inside Exif
- **WHEN** ExifIFD contains an Interoperability pointer
- **THEN** the tags of that directory are in group `InteropIFD`

### Requirement: Traversal order

The library SHALL report tags in traversal order: the entries of a directory in stored order, with the tags of a sub-directory placed at the position of its pointer entry, and chained IFDs after the previous IFD and its sub-directories (observed with exiftool 13.55).

#### Scenario: Sub-directory before IFD1
- **WHEN** IFD0 contains a SubIFDs pointer and an Exif pointer and links to IFD1
- **THEN** the result lists IFD0 tags, then SubIFD tags, then ExifIFD and InteropIFD tags, then IFD1 tags

### Requirement: Pointer entries

The library SHALL NOT report the pointer entries (0x8769, 0x8825, 0xA005, 0x014A) as tags. Each directory it reads SHALL be listed in the result's directory list with its group, file offset, entry count and next-IFD offset.

#### Scenario: Directory list
- **WHEN** a fixture with IFD0, ExifIFD and GPS is read
- **THEN** no ExifOffset or GPSInfo tag is reported and the directory list contains the three directories with their offsets and entry counts

### Requirement: Value location

The library SHALL report for every tag its tag ID, field type, count, the file offset of its IFD entry and the file offset and byte length of its value.

#### Scenario: Offset of an out-of-line value
- **WHEN** Make is stored as an 8-byte ASCII string at file offset 110
- **THEN** the Make tag reports value offset 110 and value length 8

### Requirement: Bounds safety

The library SHALL check every offset and length against the file size before reading. A value that extends beyond the file SHALL be skipped with a warning. A directory whose entry table does not fit in the file SHALL be skipped entirely with a warning (observed exiftool behaviour: "Bad IFD0 directory"), and reading SHALL continue with the remaining structure.

#### Scenario: Out-of-bounds sub-directory
- **WHEN** the ExifIFD pointer is 99999 in a file of 50 bytes
- **THEN** the IFD0 tags are returned and a warning reports the bad ExifIFD directory

#### Scenario: Truncated IFD0
- **WHEN** IFD0 declares 3 entries but the file ends after 12 bytes of its entry table
- **THEN** the result contains the File group tags, no IFD0 tags, and a warning reports the bad IFD0 directory

#### Scenario: Value beyond end of file
- **WHEN** an ASCII entry points to an offset 4 bytes before the end of the file with count 20
- **THEN** that tag is skipped with a warning and the other entries of the directory are returned

### Requirement: Cycle detection

The library SHALL read each directory offset at most once. A pointer or next-IFD offset that refers to a directory already read SHALL produce a warning and SHALL NOT be followed. This deliberately differs from exiftool 13.55, which re-reads such a directory once.

#### Scenario: IFD0 links back to itself
- **WHEN** IFD0's next-IFD offset points to IFD0
- **THEN** the IFD0 tags are returned once, no IFD1 group exists, and a warning reports the loop

### Requirement: Resource limits

The library SHALL bound the work done for any input: at most a fixed number of directories per file and a fixed nesting depth, documented in the API. Values larger than a documented size threshold SHALL NOT be loaded; such tags SHALL still be reported with field type, count, value offset and length.

#### Scenario: Too many directories
- **WHEN** a fixture chains more IFDs than the directory limit
- **THEN** reading stops following the chain at the limit, returns the tags read so far, and adds a warning

#### Scenario: Large binary value
- **WHEN** a tag holds 1 MiB of UNDEFINED data
- **THEN** the tag is reported with its offset and length, and its value is not loaded into memory

### Requirement: No traps on malformed input

The library SHALL NOT crash, trap, hang or allocate memory proportional to declared counts rather than actual file size, for any input bytes. Malformed structure SHALL produce warnings or errors.

#### Scenario: Random bytes after a valid header
- **WHEN** a fuzz test reads many files consisting of a valid TIFF header followed by random bytes
- **THEN** every read finishes without a crash and returns a result or an error
