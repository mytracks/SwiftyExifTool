import Foundation

/// Lookup of tag definitions by table and ID, built once.
enum TagRegistry {
    static let definitions: [TagDefinition] = TIFFTags.all + ExifTags.all + GPSTags.all + InteropTags.all + EmbeddedBlockTags.all

    private static let main: [UInt16: TagDefinition] = index(.main)
    private static let gps: [UInt16: TagDefinition] = index(.gps)

    private static func index(_ table: TagTable) -> [UInt16: TagDefinition] {
        var result: [UInt16: TagDefinition] = [:]
        for definition in definitions where definition.table == table {
            precondition(result[definition.id] == nil, "duplicate definition for 0x\(String(definition.id, radix: 16))")
            result[definition.id] = definition
        }
        return result
    }

    static func definition(table: TagTable, id: UInt16) -> TagDefinition? {
        switch table {
        case .main: main[id]
        case .gps: gps[id]
        }
    }
}
