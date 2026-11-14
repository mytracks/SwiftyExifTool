# Implementation notes

## Real-file check (task 9.2)

Four CC0 samples from raw.pixls.us were read and compared with
`exiftool -j -a -G1 [-n]` (13.55) for the groups `File`, `IFD0`–`IFD3`,
`SubIFD*`, `ExifIFD`, `GPS` and `InteropIFD`. The files were kept in a
temporary directory and not committed:

| File | Source |
|---|---|
| `compressed_14_bit.NEF` | Nikon D750, raw.pixls.us/data/Nikon/D750/ |
| `_DSC0009.ARW` | Sony ILCE-7M3, raw.pixls.us/data/Sony/ILCE-7M3/ |
| `5G4A9394.CR2` | Canon EOS 5D Mark III, raw.pixls.us/data/Canon/EOS 5D Mark III/ |
| `compress.dng` | Canon EOS 5D Mark III, same directory |

All TIFF 6.0 and Exif/GPS tags defined by this change matched in name,
value and display text, with no warnings.

Fixed during the check:

- 0x0201/0x0202 are named `JpgFromRaw…` only in the group `SubIFD`; in
  `SubIFD1`, `SubIFD2`, … they are `OtherImage…` (fixture `tiff-jpeg-pointers`).
- exiftool trims trailing spaces only for some ASCII tags; an ARW with an
  all-space ImageDescription showed it. Now observed per tag (fixture
  `ascii-trailing-spaces`) and the exif-tags spec requirement "Strings"
  was refined accordingly.

Follow-ups, all expected and out of scope here (roadmap entry 4 unless noted):

- File type detection for NEF, ARW, CR2 and DNG (FileType, extension, MIME type).
- Compression values 7 (JPEG), 32767 (Sony ARW), 34713 (Nikon NEF) and
  PhotometricInterpretation 32803 (Color Filter Array): defined by the DNG
  specification and vendors, not by TIFF 6.0.
- DNG tags (DNGVersion, ColorMatrix1, …) and the TIFF/EP tags DNG uses
  (CFARepeatPatternDim 0x828D, CFAPattern2 0x828E, TIFF-EPStandardID 0x9216,
  SensingMethod 0x9217).
- Format-dependent names: IFD0 0x0201/0x0202 are `PreviewImage…` in ARW
  and CR2; CR2's IFD0 strips are the preview.
- Vendor tags in SubIFDs and extra IFDs (Sony 0x7000–0x74C8, Canon
  0xC5D8–0xC6DC): vendor changes.
- Interoperability tag 0x0002 (InteropVersion): no source available yet;
  reported as `Exif_0x0002`.
- Derived tags (`PreviewImage`, `ThumbnailImage`, `ThumbnailTIFF`,
  `JpgFromRaw`, `OtherImage`) are listed with embedded previews in entry 4.

## Sources added during implementation

- CIPA DC-008-2026 (Exif 3.1) replaces DC-008-2023 (Exif 3.0) as the Exif
  source; the specs and design now cite it.
- XMP Specification Part 3 (Table 12) for tags 700 and 33723; ICC Technical
  Note "Embedding ICC profiles" for tag 34675; Adobe PageMaker 6.0 TIFF
  Technical Notes (TIFF Tech Note 1) for SubIFDs 330. These replaced IDs
  that had initially been taken from memory.
