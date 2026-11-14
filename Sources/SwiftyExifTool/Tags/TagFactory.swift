import Foundation

/// Builds ``Tag`` values from stored fields and tag definitions.
enum TagFactory {
    static func makeTag(table: TagTable, group: TagGroup, id: UInt16, stored: StoredValue, location: ValueLocation,
                        byteOrder: ByteOrder) -> Tag {
        let definition = TagRegistry.definition(table: table, id: id)
        let value = convertValue(stored, conversion: definition?.value ?? .automatic, byteOrder: byteOrder,
                                 trimSpaces: definition?.trimsTrailingSpaces ?? false)
        let display = definition.map { displayText(value: value, stored: stored, conversion: $0.display) } ?? value.exiftoolText
        return Tag(
            group: group,
            name: definition?.name(in: group) ?? unknownName(table: table, id: id),
            id: id,
            isUnknown: definition == nil,
            stored: stored,
            value: value,
            displayText: display,
            location: location
        )
    }

    /// Names of tags without a definition (observed with `exiftool -u`, 13.55).
    static func unknownName(table: TagTable, id: UInt16) -> String {
        let hex = String(format: "%04x", id)
        return table == .gps ? "GPS_0x\(hex)" : "Exif_0x\(hex)"
    }

    /// The value as `exiftool -n` prints it.
    static func convertValue(_ stored: StoredValue, conversion: ValueConversion, byteOrder: ByteOrder,
                             trimSpaces: Bool = false) -> TagValue {
        if case .text(let data) = stored.contents, case .automatic = conversion {
            return .string(ValueFormatting.text(data, trimSpaces: trimSpaces))
        }
        if case .notLoaded = stored.contents { return .binary(length: Int(stored.count) * stored.fieldType.size) }
        switch conversion {
        case .binary:
            return .binary(length: Int(stored.count) * stored.fieldType.size)
        case .binaryOfText:
            return .binary(length: automaticValue(stored.contents).exiftoolText.utf8.count)
        case .undefinedText:
            if case .bytes(let data) = stored.contents { return .string(ValueFormatting.text(data)) }
            return automaticValue(stored.contents)
        case .automatic:
            return automaticValue(stored.contents)
        case .apexShutterSpeed:
            guard let v = singleNumber(stored) else { return automaticValue(stored.contents) }
            return .double(pow(2, -v))
        case .apexAperture:
            guard let v = singleNumber(stored) else { return automaticValue(stored.contents) }
            return .double(pow(2, v / 2))
        case .characterCodedText:
            guard case .bytes(let data) = stored.contents else { return automaticValue(stored.contents) }
            return .string(ValueConversions.characterCodedText(data, byteOrder: byteOrder))
        case .cfaPattern:
            guard case .bytes(let data) = stored.contents,
                  let pattern = ValueConversions.cfaPattern(data, byteOrder: byteOrder)
            else { return automaticValue(stored.contents) }
            return .string(([pattern.width, pattern.height] + pattern.colors).map(String.init).joined(separator: " "))
        case .undefinedRationals:
            guard case .bytes(let data) = stored.contents else { return automaticValue(stored.contents) }
            return automaticValue(.rationals(ValueConversions.rationals(data, byteOrder: byteOrder)))
        case .gpsCoordinate:
            guard case .rationals(let r) = stored.contents, r.count == 3 else { return automaticValue(stored.contents) }
            let parts = r.map { $0.denominator == 0 ? 0 : Double($0.numerator) / Double($0.denominator) }
            return .double(parts[0] + parts[1] / 60 + parts[2] / 3600)
        case .gpsTimeStamp:
            guard case .rationals(let r) = stored.contents, r.count == 3 else { return automaticValue(stored.contents) }
            let parts = r.map { $0.denominator == 0 ? 0 : Double($0.numerator) / Double($0.denominator) }
            return .string(ValueConversions.timeStamp(seconds: parts[0] * 3600 + parts[1] * 60 + parts[2]))
        }
    }

    /// The single numeric value of a field, if it has exactly one.
    static func singleNumber(_ stored: StoredValue) -> Double? {
        switch automaticValue(stored.contents) {
        case .integer(let v): Double(v)
        case .double(let v): v
        default: nil
        }
    }

    static func automaticValue(_ contents: StoredValue.Contents) -> TagValue {
        func list(_ values: [TagValue]) -> TagValue {
            values.count == 1 ? values[0] : .string(ValueFormatting.joined(values.map(\.exiftoolText)))
        }
        switch contents {
        case .bytes(let data):
            return list(data.map { .integer(Int64($0)) })
        case .text(let data):
            return .string(ValueFormatting.text(data))
        case .unsigned(let v):
            return list(v.map { .integer(Int64($0)) })
        case .signed(let v):
            return list(v.map { .integer(Int64($0)) })
        case .rationals(let v):
            return list(v.map { ValueFormatting.rational(numerator: Int64($0.numerator), denominator: Int64($0.denominator)) })
        case .signedRationals(let v):
            return list(v.map { ValueFormatting.rational(numerator: Int64($0.numerator), denominator: Int64($0.denominator)) })
        case .floats(let v):
            return floatingList(v.map(Double.init))
        case .doubles(let v):
            return floatingList(v)
        case .notLoaded:
            return .binary(length: 0)
        }
    }

    private static func floatingList(_ values: [Double]) -> TagValue {
        if values.count == 1 { return .double(values[0]) }
        return .string(ValueFormatting.joined(values.map(ValueFormatting.floatingText)))
    }

    static func displayText(value: TagValue, stored: StoredValue, conversion: DisplayConversion) -> String {
        switch conversion {
        case .none:
            return plainText(value, stored: stored)
        case .enumeration(let map):
            guard let key = value.integerValue else { return plainText(value, stored: stored) }
            return map[key] ?? "Unknown (\(key))"
        case .stringEnumeration(let map):
            guard case .string(let key) = value else { return plainText(value, stored: stored) }
            return map[key] ?? "Unknown (\(key))"
        case .enumerationList(let map, let separator):
            let items = integerItems(stored)
            guard !items.isEmpty else { return plainText(value, stored: stored) }
            return items.map { map[$0] ?? "Unknown (\($0))" }.joined(separator: separator)
        case .bitField(let names):
            guard let bits = value.integerValue else { return plainText(value, stored: stored) }
            if bits == 0 { return "(none)" }
            return (0 ..< 64).filter { bits & (1 << $0) != 0 }.map { names[$0] ?? "[\($0)]" }.joined(separator: ", ")
        case .formatter(let formatter):
            return Formatters.apply(formatter, value: value, stored: stored)
        }
    }

    /// The stored integers of a field, or an empty list for other types.
    static func integerItems(_ stored: StoredValue) -> [Int64] {
        switch stored.contents {
        case .unsigned(let v): v.map(Int64.init)
        case .signed(let v): v.map(Int64.init)
        case .bytes(let d): d.map(Int64.init)
        default: []
        }
    }

    /// The value's text, using FLOAT/DOUBLE precision where appropriate.
    static func plainText(_ value: TagValue, stored: StoredValue) -> String {
        if case .double(let v) = value, stored.fieldType == .float || stored.fieldType == .double {
            return ValueFormatting.floatingText(v)
        }
        return value.exiftoolText
    }

    /// The text of a computed double value, with 15 significant digits
    /// (observed for APEX and GPS conversions).
    static func computedText(_ value: TagValue) -> String {
        if case .double(let v) = value { return ValueFormatting.floatingText(v) }
        return value.exiftoolText
    }
}
