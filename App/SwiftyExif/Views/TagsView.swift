import SwiftUI
import SwiftyExifTool

/// The tag list: a table in regular width, a list on iPhone and in narrow
/// iPad layouts.
struct TagsView: View {
    @Bindable var model: InspectorModel
    /// Set when a single group is selected in the sidebar.
    let groupFilter: TagGroup?
    @State private var selection: Set<TagRow.ID> = []
    @State private var showsDetails = false
    /// Whether the tag view is too narrow for all table columns, e.g. on an
    /// iPad in portrait with the sidebar and the details both open.
    @State private var isNarrow = false
    /// Clicking a row does not move keyboard focus away from the sidebar on
    /// macOS, so the table takes it on selection; Cmd-C (`copyable`) needs it.
    @FocusState private var isTableFocused: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Below this width the table cannot show its columns side by side.
    private static let minTableWidth: CGFloat = 680

    /// Two-line rows on iPhone and in narrow iPad layouts; macOS tables
    /// scroll horizontally instead.
    private var usesList: Bool {
        #if os(macOS)
        false
        #else
        sizeClass == .compact || isNarrow
        #endif
    }

    private var sections: [GroupSection] {
        var query = model.query
        if let groupFilter { query.groups = (query.groups ?? [groupFilter]).intersection([groupFilter]) }
        return query.sections(for: model.file?.rows ?? [])
    }

    private var allRows: [TagRow] { sections.flatMap(\.rows) }

    private var selectedRows: [TagRow] { allRows.filter { selection.contains($0.id) } }

    var body: some View {
        content
            .onGeometryChange(for: Bool.self) { $0.size.width < Self.minTableWidth } action: { isNarrow = $0 }
            .searchable(text: $model.query.searchText, prompt: "Name, ID, value or text")
            .toolbar { FilterMenu(model: model) }
            .inspector(isPresented: $showsDetails) {
                Group {
                    if let row = selectedRows.first {
                        TagDetailView(row: row)
                    } else {
                        ContentUnavailableView("No Tag Selected", systemImage: "tag")
                    }
                }
                .inspectorColumnWidth(min: 260, ideal: 320, max: 520)
            }
            .onChange(of: selection) {
                guard !selection.isEmpty else { return }
                showsDetails = true
                if !usesList { isTableFocused = true }
            }
            .onChange(of: model.file?.url) { selection = [] }
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView.search(text: model.query.searchText)
                }
            }
    }

    @ViewBuilder private var content: some View {
        if usesList { tagList } else { tagTable }
    }

    /// iOS lists select rows only in edit mode and reset a bound selection
    /// on tap, so each row is a button that selects itself and opens the
    /// details, with its own context menu.
    private var tagList: some View {
        List {
            ForEach(sections) { section in
                Section(section.group.rawValue) {
                    ForEach(section.rows) { row in
                        Button {
                            selection = [row.id]
                            showsDetails = true
                        } label: {
                            CompactTagRow(row: row)
                        }
                        .tint(.primary)
                        .listRowBackground(selection.contains(row.id) ? Color.accentColor.opacity(0.15) : nil)
                        .contextMenu { menu([row.id]) }
                    }
                }
            }
        }
    }

    private var tagTable: some View {
        Table(of: TagRow.self, selection: $selection) {
            TableColumn("Name") { row in NameCell(row: row) }
                .width(min: 170, ideal: 220)
            TableColumn("ID") { row in Text(row.idText ?? "").monospaced() }
                .width(70)
            TableColumn("Type") { row in Text(row.typeText ?? "") }
                .width(82)
            // Wide enough for seven digits (e.g. 1048576 for a 1 MiB value).
            TableColumn("Count") { row in Text(row.countText ?? "").monospacedDigit() }
                .width(min: 48, ideal: 72)
            TableColumn("Value") { row in Text(row.valueText).lineLimit(1) }
                .width(min: 70, ideal: 140)
            TableColumn("Display") { row in Text(row.displayText).lineLimit(1) }
                .width(min: 120, ideal: 240)
            TableColumn("Offset") { row in Text(row.offsetText ?? "").monospacedDigit() }
                .width(64)
        } rows: {
            tableRows
        }
        .contextMenu(forSelectionType: TagRow.ID.self) { ids in menu(ids) }
        .focused($isTableFocused)
        // SwiftUI's Table crashes when the number of row sections changes
        // in an update (index out of range in TableRowForEachState), so
        // the table is rebuilt whenever the visible sections change.
        .id(TableIdentity(file: model.file?.url, query: model.query, groupFilter: groupFilter))
        #if os(macOS)
        .copyable(selectedRows.map(CopyText.row))
        #endif
    }

    @TableRowBuilder<TagRow> private var tableRows: some TableRowContent<TagRow> {
        #if os(iOS)
        // iOS tables never show the header of their first section, so an
        // empty section without a header goes first.
        Section { ForEach([TagRow]()) { TableRow($0) } }
        #endif
        ForEach(sections) { section in
            Section(section.group.rawValue) {
                ForEach(section.rows) { TableRow($0) }
            }
        }
    }

    @ViewBuilder private func menu(_ ids: Set<TagRow.ID>) -> some View {
        let rows = allRows.filter { ids.contains($0.id) }
        if rows.count == 1, let row = rows.first {
            Button("Copy Value") { model.copyValue(row) }
            Button("Copy Display Text") { model.copyDisplay(row) }
        }
        if !rows.isEmpty {
            Button(rows.count == 1 ? "Copy Row" : "Copy \(rows.count) Rows") { model.copyRows(rows) }
        }
    }
}

private struct TableIdentity: Hashable {
    let file: URL?
    let query: TagQuery
    let groupFilter: TagGroup?
}

private struct NameCell: View {
    let row: TagRow

    var body: some View {
        HStack(spacing: 4) {
            Text(row.name)
                .foregroundStyle(row.isUnknown ? .secondary : .primary)
            if row.isUnknown {
                Text("?")
                    .font(.caption2.bold())
                    .help("Unknown tag: the library has no definition for this ID")
                    .padding(.horizontal, 4)
                    .background(.orange.opacity(0.25), in: Capsule())
            }
        }
    }
}

private struct CompactTagRow: View {
    let row: TagRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                NameCell(row: row)
                Spacer()
                Text(row.displayText).foregroundStyle(.secondary).lineLimit(1)
            }
            Text([row.idText, row.typeText, row.countText.map { "×\($0)" }, row.valueText]
                .compactMap { $0 }.joined(separator: "  "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Group selection and unknown-tag filter.
struct FilterMenu: View {
    @Bindable var model: InspectorModel

    var body: some View {
        Menu("Filter", systemImage: model.query.groups == nil && !model.query.hideUnknown
             ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") {
            Toggle("Hide Unknown Tags", isOn: $model.query.hideUnknown)
            Divider()
            Button("All Groups") { model.query.groups = nil }
            ForEach(model.file?.groups.map(\.group) ?? [], id: \.self) { group in
                Toggle(group.rawValue, isOn: binding(for: group))
            }
        }
    }

    private func binding(for group: TagGroup) -> Binding<Bool> {
        Binding {
            model.query.groups?.contains(group) ?? true
        } set: { isOn in
            let all = Set(model.file?.groups.map(\.group) ?? [])
            var groups = model.query.groups ?? all
            if isOn { groups.insert(group) } else { groups.remove(group) }
            model.query.groups = groups == all ? nil : groups
        }
    }
}
