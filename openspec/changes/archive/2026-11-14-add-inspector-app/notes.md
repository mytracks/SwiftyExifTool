# Implementation notes

## Real-file check (task 5.2)

The four CC0 samples of the `add-tiff-exif-reading` check were downloaded
again from raw.pixls.us into a temporary directory (not committed) and
opened in the sandboxed macOS app with `open -a`:

| File | Size | Tags | Directories | Warnings |
|---|---|---|---|---|
| `compressed_14_bit.NEF` (Nikon D750) | 21.8 MB | 96 | 6 | 0 |
| `_DSC0009.ARW` (Sony ILCE-7M3) | 24.5 MB | 116 | 5 | 0 |
| `5G4A9394.CR2` (Canon EOS 5D Mark III) | 24.8 MB | 82 | 7 | 0 |
| `compress.dng` (Canon EOS 5D Mark III) | 1.5 MB | 55 | 2 | 0 |

- The counts in the sidebar and the summary match those of
  `MetadataReader.read(contentsOf:)` called directly on the same files.
- Each read takes about 1 ms (bounded reads), so the interface stays
  responsive and the progress view is barely visible.
- Opening two files back to back (`open -a` twice: NEF→CR2, CR2→ARW,
  ARW→DNG) always left one window showing the second file. A read is too
  short to be superseded on purpose with real files; the unit test
  `supersededReadIsDiscarded` covers that case with a slow reader.

## Platform findings

- iPadOS 18 and later do not deliver drops from other apps onto SwiftUI
  lists, forms and tables (FB15618535); see design D4.
- The iPad simulators of Xcode 27 crash (`backboardd`, Metal assertion in
  `MTLSimDevice newTextureWithDescriptor`) as soon as two app windows are
  visible, so drops between apps were checked on a device.
- A `WindowGroup` opened a second window when macOS restored a window and
  a file was opened at launch; macOS therefore uses a single `Window`
  scene (design D4).
- The "Open With" check used `.nef` copies of fixtures in addition to the
  real NEF; the default apps for `.nef` and `.tif` were unchanged
  afterwards. Only the current macOS was checked, not macOS 14.
