/// Tags whose values are embedded metadata blocks. They are reported as
/// undecoded binary tags; later changes decode their content.
/// IDs from the cited documents; names observed with `exiftool -v2`
/// (fixture `embedded-blocks`).
enum EmbeddedBlockTags {
    static let all: [TagDefinition] = [
        TagDefinition(0x02BC, "ApplicationNotes", value: .binary, source: .xmpPart3("Table 12 (XMP packet, tag 700)")),
        TagDefinition(0x83BB, "IPTC-NAA", value: .binary, source: .xmpPart3("Table 12 (IPTC dataset, tag 33723)")),
        TagDefinition(0x8773, "ICC_Profile", value: .binary,
                      source: .specification(.iccEmbedding, section: "TIFF, Table 2 (tag 34675)")),
        TagDefinition(0x927C, "MakerNoteUnknown", value: .binary, source: .exif("4.6.6.4.1 (MakerNote)")),
    ]

    /// IDs that exiftool hides from its JSON output (it decodes or omits them).
    static let hiddenByExiftool: Set<UInt16> = [0x02BC, 0x83BB, 0x8773, 0x927C]
}
