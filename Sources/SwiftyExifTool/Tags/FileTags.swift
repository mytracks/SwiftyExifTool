/// Tags of the `File` group. Names, values and display texts observed with
/// exiftool 13.55 (fixtures `basic-le`, `basic-be`).
enum FileTags {
    static func make(fileType: FileType, byteOrder: ByteOrder?) -> [Tag] {
        var tags = [
            tag("FileType", .string(fileType.name), fileType.name),
            tag("FileTypeExtension", .string(fileType.fileExtension), fileType.fileExtension.lowercased()),
            tag("MIMEType", .string(fileType.mimeType), fileType.mimeType),
        ]
        switch byteOrder {
        case .littleEndian: tags.append(tag("ExifByteOrder", .string("II"), "Little-endian (Intel, II)"))
        case .bigEndian: tags.append(tag("ExifByteOrder", .string("MM"), "Big-endian (Motorola, MM)"))
        case nil: break
        }
        return tags
    }

    private static func tag(_ name: String, _ value: TagValue, _ display: String) -> Tag {
        Tag(group: .file, name: name, id: nil, isUnknown: false, stored: nil, value: value, displayText: display, location: nil)
    }
}
