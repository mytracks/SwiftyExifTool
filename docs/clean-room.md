# Clean-room policy

SwiftyExifTool is MIT-licensed. ExifTool is distributed under the same terms
as Perl (Artistic License or GPL), and most other metadata libraries are GPL
or LGPL. To keep the MIT licence, nothing in this repository may be derived
from their code or their tag tables. This policy is binding for everyone who
contributes, human or AI assistant.

This is a risk-reduction process, not legal advice.

## Forbidden sources

Do not open, copy, translate, summarise or feed to any tool:

- ExifTool's source: the `exiftool` script and every module under
  `lib/Image/ExifTool/`, including its tag tables.
- ExifTool's generated tag documentation (`TagNames` pages, POD) and bulk
  dumps of its tag database (`exiftool -listx`, `-list`, `-listw`, `-listf`
  and similar).
- Exiv2, libexif, LibRaw, dcraw, rawspeed, and any other GPL, LGPL or
  unlicensed metadata or RAW code.
- Documents that reproduce tables from any of the above.

## Allowed sources

- Published specifications: TIFF 6.0, TIFF/EP (ISO 12234-2), CIPA DC-008
  (Exif), Adobe DNG Specification, XMP Specification Parts 1–3 / ISO 16684-1,
  ISO/IEC 14496-12 (ISO BMFF), IPTC Photo Metadata Standard.
- Vendor documentation.
- Independent format write-ups whose own licence allows use and that are not
  copies of forbidden tables. Record the URL.
- Black-box observation of the `exiftool` binary on individual fixture files,
  for example:
  - `exiftool -j -a -G1 -n <file>` and `exiftool -j -a -G1 <file>`
  - `exiftool -v3 <file>` and `exiftool -htmldump <file>` (structure, offsets)
  - `exiftool -validate -warning -a <file>`

Tag names, group names and value formatting may follow exiftool's observable
output, so that results stay interchangeable with exiftool's.

Observation has one limit: fixtures may only contain tag IDs that come from a
published specification or from a definition that is already sourced, plus
deliberately private IDs for structural tests. Filling fixtures with every
possible tag ID to harvest the names exiftool knows would amount to dumping
its tag database and is forbidden.

## Provenance

Every tag or format definition that does not come from a published
specification records where it came from:

- a document (title, version, section, or URL), or
- an observation: fixture identifier, the exiftool command, and the exiftool
  version.

Recollection is not provenance. Knowledge remembered by a person or an AI
assistant must be confirmed against an allowed source or a black-box
observation before it is added. If a definition cannot be sourced, stop and
ask the maintainer.

## Fixtures

- Commit only files that you created yourself or that carry an explicit
  licence that allows it (e.g. CC0 samples), and record source and licence.
- Never commit personal photos: they can carry GPS coordinates, serial
  numbers and owner names.
- Keep committed fixtures small. Large sample RAW files stay outside git and
  are described by a manifest instead.
