# ``SwiftyExifTool``

Read image metadata, with a focus on camera RAW files, on macOS, iOS and iPadOS.

## Overview

SwiftyExifTool reads TIFF-structured metadata: the IFD chain, SubIFDs, and
the Exif, GPS and Interoperability directories. Tag names, groups, values and
display texts follow exiftool's output, so results are interchangeable with
`exiftool -j -a -G1 [-n]`.

```swift
let metadata = try MetadataReader.read(contentsOf: url)
for tag in metadata.tags {
    print("\(tag.group):\(tag.name) = \(tag.displayText)")
}
```

Reading never modifies files, reads only the byte ranges the metadata points
to, and reports problems in damaged files as ``ReadWarning``s instead of
failing.

## Topics

### Reading

- ``MetadataReader``
- ``ReadingLimits``
- ``ReadError``
- ``DetectedFormat``

### Results

- ``Metadata``
- ``Tag``
- ``TagGroup``
- ``TagValue``
- ``StoredValue``
- ``FieldType``
- ``Rational``
- ``SignedRational``
- ``ValueLocation``
- ``Directory``
- ``ReadWarning``
- ``FileType``
- ``ByteOrder``
