import Foundation

/// Fields that can identify a person. Corpus snapshots store them only as
/// hashes; the comparison hashes the library's text the same way
/// (exiftool-conformance spec, "Personal fields are hashed"; design D4).
/// Extend the list when a change adds personal fields, e.g. from MakerNotes.
public enum PersonalFields {
    /// Tag names that are personal in any group.
    public static let names: Set<String> = ["Artist", "Copyright", "OwnerName"]
    /// Name suffixes that are personal in any group.
    public static let nameSuffixes = ["SerialNumber"]
    /// Groups whose tags are all personal.
    public static let groups: Set<String> = ["GPS"]

    /// The prefix of a hashed value.
    public static let prefix = "sha256:"

    /// Whether a `Group:Name` key is a personal field.
    public static func isPersonal(_ key: String) -> Bool {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return false }
        let (group, name) = (parts[0], parts[1])
        return groups.contains(group) || names.contains(name) || nameSuffixes.contains { name.hasSuffix($0) }
    }

    /// The text that is hashed: numbers with ten significant digits (as
    /// `exiftool -n` prints them), anything else as is.
    public static func canonicalText(_ value: JSONValue) -> String {
        if case .number(let text) = value, let number = Double(text) {
            return String(format: "%.10g", number)
        }
        return value.text
    }

    /// The hashed form of a value: `sha256:` and the lowercase hex SHA-256 of
    /// its canonical text.
    public static func hashed(_ value: JSONValue) -> JSONValue {
        if value.text.hasPrefix(prefix) { return value }
        return .string(prefix + Corpus.sha256(of: canonicalText(value)))
    }

    /// Whether a value is stored as a hash.
    public static func isHashed(_ value: JSONValue) -> Bool {
        if case .string(let text) = value { return text.hasPrefix(prefix) }
        return false
    }

    /// A comparison hook that hashes the library's value of a personal field
    /// when the snapshot stores that field hashed.
    public static let prepare: Conformance.Prepare = { key, actual, expected in
        isPersonal(key) && isHashed(expected) ? hashed(actual) : actual
    }
}
