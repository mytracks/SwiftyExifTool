import SwiftUI
import SwiftyExifTool
import UniformTypeIdentifiers

/// What the sidebar selects.
enum SidebarItem: Hashable {
    case summary
    case allTags
    case group(TagGroup)
    case directories
    case warnings
}

struct ContentView: View {
    @Bindable var model: InspectorModel
    @Binding var isImporting: Bool
    @State private var sidebarSelection: SidebarItem? = .allTags
    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model, selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem {
                Button("Open", systemImage: "folder") { isImporting = true }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item]) { result in
            // Cancelling keeps the current file.
            if case .success(let url) = result { model.open(url) }
        }
        .modifier(FileDrop(model: model, isTargeted: $isDropTargeted))
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12).stroke(.tint, lineWidth: 3).padding(4).allowsHitTesting(false)
            }
        }
        .onChange(of: model.file?.url) { sidebarSelection = .allTags }
        .navigationTitle(title)
    }

    private var title: String {
        switch model.state {
        case .empty: "SwiftyExif"
        case .loading(let url), .failed(let url, _): url.lastPathComponent
        case .loaded(let file): file.displayName
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.state {
        case .empty:
            ContentUnavailableView {
                Label("No File", systemImage: "doc.viewfinder")
            } description: {
                Text("Open a TIFF or RAW file, or drop one here, to see its metadata.")
            } actions: {
                Button("Open…") { isImporting = true }
            }
        case .loading(let url):
            ProgressView("Reading \(url.lastPathComponent)…")
        case .failed(let url, let error):
            ContentUnavailableView {
                Label(url.lastPathComponent, systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.userMessage)
            } actions: {
                Button("Open Another File…") { isImporting = true }
            }
        case .loaded(let file):
            switch sidebarSelection ?? .allTags {
            case .summary: SummaryView(file: file)
            case .allTags: TagsView(model: model, groupFilter: nil)
            case .group(let group): TagsView(model: model, groupFilter: group)
            case .directories: DirectoriesView(directories: file.metadata.directories)
            case .warnings: WarningsView(warnings: file.metadata.warnings)
            }
        }
    }
}

/// Drag and drop: file URLs on macOS, imported file copies on iPadOS.
private struct FileDrop: ViewModifier {
    let model: InspectorModel
    @Binding var isTargeted: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        content.dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: \.isFileURL) else { return false }
            model.open(url)
            return true
        } isTargeted: { isTargeted = $0 }
        #else
        content.dropDestination(for: DroppedFile.self) { files, _ in
            guard let file = files.first else { return false }
            model.open(file.url, displayName: file.name)
            return true
        } isTargeted: { isTargeted = $0 }
        #endif
    }
}

/// A dropped file, copied into the app's temporary directory because the
/// system removes its own copy after the import returns.
struct DroppedFile: Transferable {
    let url: URL
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            let name = received.file.lastPathComponent
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dropped-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let copy = directory.appendingPathComponent(name)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return DroppedFile(url: copy, name: name)
        }
    }
}

struct Sidebar: View {
    let model: InspectorModel
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            if let file = model.file {
                Label("Summary", systemImage: "info.circle").tag(SidebarItem.summary)
                Section("Tags") {
                    row("All Tags", "list.bullet", count: file.tagCount).tag(SidebarItem.allTags)
                    ForEach(file.groups, id: \.group) { item in
                        row(item.group.rawValue, "folder", count: item.count).tag(SidebarItem.group(item.group))
                    }
                }
                Section("Structure") {
                    row("Directories", "square.stack.3d.up", count: file.directoryCount).tag(SidebarItem.directories)
                    row("Warnings", "exclamationmark.triangle", count: file.warningCount).tag(SidebarItem.warnings)
                }
            }
        }
        .navigationTitle("SwiftyExif")
    }

    private func row(_ title: String, _ image: String, count: Int) -> some View {
        Label(title, systemImage: image).badge(count)
    }
}
