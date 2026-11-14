/// Tags of the Interoperability IFD (CIPA DC-008-2026, 4.6.8). They share
/// the main table with the other IFDs.
///
/// Exif 3.1 defines only InteroperabilityIndex. Other Interoperability tags
/// (e.g. 0x0002) are defined by documents not yet available as sources and
/// are reported as unknown tags until then.
enum InteropTags {
    static let all: [TagDefinition] = [
        // R98 and THM: 4.6.8.1.1; R03 and all texts observed (fixture `interop-index`).
        TagDefinition(0x0001, "InteropIndex", display: .stringEnumeration([
            "R98": "R98 - DCF basic file (sRGB)",
            "THM": "THM - DCF thumbnail file",
            "R03": "R03 - DCF option file (Adobe RGB)",
        ]), source: .exif("4.6.8.1.1 (InteroperabilityIndex)")),
    ]
}
