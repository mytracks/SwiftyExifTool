# Spec Delta

## Purpose

The public entry point for reading metadata: what callers pass in, what they
get back (tags, groups, values, directory structure, warnings), which errors
they must handle, and the resource and concurrency guarantees they can rely
on in apps and tools on macOS, iOS and iPadOS.

## ADDED Requirements

### Requirement: Read from a file URL

The library SHALL read metadata from a file URL. It SHALL open the file read-only, never modify it, and not keep it open after the call returns. Gaining security-scoped access on iOS and iPadOS is the caller's responsibility and SHALL be documented.

#### Scenario: Read a fixture file
- **WHEN** a caller reads the URL of a valid TIFF fixture
- **THEN** a result with the fixture's tags is returned

#### Scenario: File is left untouched
- **WHEN** a fixture file is read
- **THEN** its bytes and modification date are unchanged afterwards

### Requirement: Read from data

The library SHALL read metadata from an in-memory byte buffer with the same results as reading the same bytes from a file.

#### Scenario: Data and file agree
- **WHEN** the same fixture is read once from its URL and once from its bytes in memory
- **THEN** both results are equal

### Requirement: Bounded reading

When reading from a file, the library SHALL read only the byte ranges the metadata structure points to, so the amount of data read depends on the metadata, not on the file size.

#### Scenario: Large file with small metadata
- **WHEN** a 200 MB file consists of a small TIFF header and IFD0 followed by image data
- **THEN** reading it reads less than 1 MB from the file

### Requirement: Result model

A result SHALL contain the detected file type, the byte order, the tags in traversal order, the list of directories read, and the warnings. Each tag SHALL carry its group, name, tag ID, unknown flag, stored value, value, display text and value location.

#### Scenario: Complete tag record
- **WHEN** a fixture with IFD0:Orientation stored as SHORT 6 at a known offset is read
- **THEN** the tag reports group `IFD0`, name `Orientation`, ID 0x0112, not unknown, field type SHORT, count 1, value 6, display text `Rotate 90 CW` and its offsets

### Requirement: Tag lookup

The result SHALL allow looking up tags by group and name, returning the matching tag if present, and by name alone, returning all matching tags in traversal order.

#### Scenario: Lookup with group
- **WHEN** a fixture has ImageWidth in IFD0 and IFD1 and the caller looks up IFD0 ImageWidth
- **THEN** only the IFD0 tag is returned

#### Scenario: Lookup by name
- **WHEN** the caller looks up ImageWidth without a group in the same fixture
- **THEN** both tags are returned, IFD0 first

### Requirement: Warnings

Recoverable problems SHALL NOT fail the read. Each problem SHALL be reported as a warning with a message, the affected group, and the file offset where known.

#### Scenario: Read with warnings
- **WHEN** a fixture with a valid IFD0 and an out-of-bounds ExifIFD pointer is read
- **THEN** the read succeeds with the IFD0 tags and one warning naming ExifIFD and the bad offset

### Requirement: Errors

The read SHALL fail with a distinct error when the file cannot be opened or read (carrying the underlying cause), when the format is recognised but unsupported (naming the format), and when the format is unknown. A detected TIFF file whose directories are all invalid SHALL NOT be an error.

#### Scenario: Missing file
- **WHEN** a caller reads a URL that does not exist
- **THEN** the read fails with a file-access error carrying the underlying cause

#### Scenario: Unsupported format
- **WHEN** a caller reads a PNG file
- **THEN** the read fails with an unsupported-format error naming PNG

#### Scenario: Broken TIFF is not an error
- **WHEN** a caller reads a TIFF whose IFD0 offset points beyond the end of the file
- **THEN** the read succeeds with the File group tags and a warning

### Requirement: Concurrency

All result types SHALL be `Sendable` and values with value semantics. Reading SHALL be safe to call from any thread or task, including concurrently for different files, and SHALL NOT require the main actor.

#### Scenario: Concurrent reads
- **WHEN** 50 fixture files are read concurrently from a task group
- **THEN** every read returns the same result as a sequential read of that file

### Requirement: Deterministic results

Reading the same bytes SHALL always produce an equal result, including tag order and warnings.

#### Scenario: Repeated read
- **WHEN** the same fixture is read twice
- **THEN** both results are equal
