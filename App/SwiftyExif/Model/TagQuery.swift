import SwiftyExifTool

/// The tags of one group as shown in the list.
struct GroupSection: Identifiable, Hashable, Sendable {
    let group: TagGroup
    let rows: [TagRow]
    var id: String { group.rawValue }
}

/// Search text and filters applied to the tag list.
struct TagQuery: Hashable, Sendable {
    var searchText = ""
    /// Groups to show; `nil` shows all groups.
    var groups: Set<TagGroup>?
    var hideUnknown = false

    var isFiltering: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty || groups != nil || hideUnknown }

    /// Sections in first-occurrence order of the groups, rows in traversal
    /// order. Groups without matching rows are left out.
    func sections(for rows: [TagRow]) -> [GroupSection] {
        var order: [TagGroup] = []
        var byGroup: [TagGroup: [TagRow]] = [:]
        for row in rows where include(row) {
            if byGroup[row.group] == nil { order.append(row.group) }
            byGroup[row.group, default: []].append(row)
        }
        return order.map { GroupSection(group: $0, rows: byGroup[$0] ?? []) }
    }

    func include(_ row: TagRow) -> Bool {
        if hideUnknown && row.isUnknown { return false }
        if let groups, !groups.contains(row.group) { return false }
        return row.matches(searchText)
    }
}
