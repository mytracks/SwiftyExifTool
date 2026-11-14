# Spec Delta

## Purpose

SwiftyExif is the debug app of the project: it opens one image file on
macOS, iOS or iPadOS and shows everything SwiftyExifTool extracts from it,
so that reading results can be inspected without writing code.

## ADDED Requirements

### Requirement: Platforms and identity

The app SHALL be named SwiftyExif, use the bundle identifier `info.stichling.SwiftyExif`, and run on macOS 14, iOS 17 and iPadOS 17 or later from a single code base that uses only the SwiftyExifTool library and Apple frameworks.

#### Scenario: Builds for all platforms
- **WHEN** the app is built for macOS and for an iOS simulator
- **THEN** both builds succeed and the app bundles carry the name SwiftyExif and the bundle identifier `info.stichling.SwiftyExif`

### Requirement: Open with the file picker

The app SHALL let the user choose one file with the system file picker on every platform and then show its metadata.

#### Scenario: Pick a TIFF
- **WHEN** the user picks a TIFF fixture in the file picker
- **THEN** the app shows the metadata of that file

#### Scenario: Picker cancelled
- **WHEN** the user cancels the file picker
- **THEN** the previously shown file, if any, stays visible unchanged

### Requirement: Open by drag and drop

On macOS and iPadOS the app SHALL accept a file dropped onto its window and show its metadata, replacing the file shown before.

#### Scenario: Drop a file
- **WHEN** a file is dropped onto the window
- **THEN** the app shows the metadata of the dropped file

### Requirement: Open With on macOS

On macOS the app SHALL appear in Finder's "Open With" menu for TIFF and camera RAW files without becoming their default application, and SHALL show the metadata of a file opened that way.

#### Scenario: Open from Finder
- **WHEN** the user chooses "Open With > SwiftyExif" for a NEF file in Finder
- **THEN** SwiftyExif opens and shows the metadata of that file

### Requirement: Read-only access

The app SHALL never modify, move or create files it opens, and SHALL only access files the user selected, holding security-scoped access for the duration of reading.

#### Scenario: File unchanged after inspection
- **WHEN** a file is opened and inspected
- **THEN** its contents and modification date are unchanged

### Requirement: Responsive reading

Reading SHALL NOT block the user interface. While a file is being read the app SHALL show a progress indication, and opening another file SHALL supersede a read in progress.

#### Scenario: Large RAW file
- **WHEN** the user opens a 50 MB RAW file
- **THEN** the interface stays responsive and shows progress until the metadata appears

#### Scenario: Second file during reading
- **WHEN** the user opens a second file while the first is still being read
- **THEN** only the second file's metadata is shown

### Requirement: Summary

For an opened file the app SHALL show its name, size, file type, byte order, number of tags, number of directories and number of warnings.

#### Scenario: Summary of basic-le
- **WHEN** the fixture `basic-le` is opened
- **THEN** the summary shows file type TIFF, little-endian byte order, its tag count and zero warnings

### Requirement: Tag list

The app SHALL list every tag of the result, grouped by tag group in the order the groups first occur, with tags in traversal order. Each row SHALL show the name, the tag ID as four hexadecimal digits, the field type, the count, the value, the display text and the value offset, leaving cells empty where the library has no information.

#### Scenario: Orientation row
- **WHEN** `basic-le` is opened
- **THEN** the group IFD0 contains a row Orientation with ID `0x0112`, type SHORT, count 1, value `6` and display text `Rotate 90 CW`

#### Scenario: File group rows
- **WHEN** `basic-le` is opened
- **THEN** the group File is listed first and its rows have no tag ID, type, count or offset

#### Scenario: Unknown tag is marked
- **WHEN** the fixture `unknown-tags` is opened
- **THEN** the row `Exif_0xc0de` is visibly marked as unknown

### Requirement: Tag details

Selecting a tag SHALL show its details: group, name, ID, unknown flag, field type, count, the stored value in full, the value, the display text, and the entry offset, value offset and value length.

#### Scenario: Stored rational
- **WHEN** the user selects ExposureTime in `basic-le`
- **THEN** the details show the stored value `1/250`, the value `0.004`, the display text `1/250` and the offsets of the entry and the value

#### Scenario: Value not loaded
- **WHEN** the user selects the 1 MiB tag in the fixture `large-undefined`
- **THEN** the details state that the value was not loaded and show its offset and length

### Requirement: Directories and warnings

The app SHALL list the directories that were read (group, offset, entry count, next-IFD offset) and every warning with its message, group and offset.

#### Scenario: Warning shown
- **WHEN** the fixture `bad-exif-pointer` is opened
- **THEN** the warning about the bad ExifIFD directory is listed with group ExifIFD and offset 99999, and the IFD0 tags are still shown

### Requirement: Read errors

When a file cannot be read, the app SHALL show the error instead of tags: the detected format for unsupported formats, a statement that the format is unknown, or the reason the file could not be accessed.

#### Scenario: Unsupported format
- **WHEN** the user opens a PNG file
- **THEN** the app states that PNG is not supported and shows no tags

### Requirement: Search

The app SHALL filter the tag list by a search text that matches, case-insensitively, the tag name, the hexadecimal tag ID, the value or the display text. Groups without matching tags SHALL be hidden while searching.

#### Scenario: Search by display text
- **WHEN** the user searches for `rotate` in `basic-le`
- **THEN** only the Orientation row in group IFD0 is shown

#### Scenario: Search by ID
- **WHEN** the user searches for `0x829a` in `basic-le`
- **THEN** only the ExposureTime row is shown

### Requirement: Filters

The app SHALL let the user restrict the list to selected groups and hide unknown tags. Filters SHALL combine with the search text.

#### Scenario: Hide unknown tags
- **WHEN** unknown tags are hidden in `unknown-tags`
- **THEN** the rows `Exif_0xc0de`, `Exif_0x0077` and `GPS_0x0077` are not shown and ImageWidth is

### Requirement: Copy

The app SHALL copy the value, the display text, or a whole row as `Group:Name<TAB>value<TAB>display text` to the system pasteboard.

#### Scenario: Copy a row
- **WHEN** the user copies the Orientation row of `basic-le`
- **THEN** the pasteboard contains `IFD0:Orientation`, a tab, `6`, a tab and `Rotate 90 CW`
