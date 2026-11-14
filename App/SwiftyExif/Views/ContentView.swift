import SwiftUI
import SwiftyExifTool
import UniformTypeIdentifiers
import os

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
            // On iOS, toolbar items and the title only appear when they are
            // attached to a column, not to the split view itself.
            detail
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Open", systemImage: "folder") { isImporting = true }
                    }
                }
                .navigationTitle(title)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item]) { result in
            // Cancelling keeps the current file.
            if case .success(let url) = result { model.open(url) }
        }
        .fileDrop(model: model, isTargeted: $isDropTargeted)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12).stroke(.tint, lineWidth: 3).padding(4).allowsHitTesting(false)
            }
        }
        .onChange(of: model.file?.url) { sidebarSelection = .allTags }
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

extension View {
    /// Opens a file dropped onto this view.
    ///
    /// On iPadOS, drops from other apps onto a `List`, `Form` or `Table` never
    /// reach a drop handler (iPadOS defect FB15618535, seen on iPadOS 18 and
    /// later), so there the window accepts drops only outside the tag list,
    /// e.g. on the empty state, the error views and the title area.
    func fileDrop(model: InspectorModel, isTargeted: Binding<Bool>) -> some View {
        modifier(FileDrop(model: model, isTargeted: isTargeted))
    }
}

/// Drop diagnostics; shown in the Xcode console and in Console.app
/// (subsystem `info.stichling.SwiftyExif`, category `drop`).
let dropLog = Logger(subsystem: "info.stichling.SwiftyExif", category: "drop")

/// Drag and drop: file URLs on macOS, imported file copies on iPadOS.
private struct FileDrop: ViewModifier {
    let model: InspectorModel
    @Binding var isTargeted: Bool

    func body(content: Content) -> some View {
        #if os(macOS)
        content.dropDestination(for: URL.self) { urls, _ in
            dropLog.debug("drop of \(urls.count) URLs")
            guard let url = urls.first(where: \.isFileURL) else { return false }
            model.open(url)
            return true
        } isTargeted: { targeted in
            dropLog.debug("targeted \(targeted)")
            isTargeted = targeted
        }
        #else
        content.dropDestination(for: DroppedFile.self) { files, _ in
            dropLog.debug("drop of \(files.count) files")
            return model.open(dropped: files)
        } isTargeted: { targeted in
            dropLog.debug("targeted \(targeted)")
            isTargeted = targeted
        }
        #endif
    }
}

extension InspectorModel {
    /// Opens the first dropped file under its original name; returns whether
    /// there was one.
    @discardableResult
    func open(dropped files: [DroppedFile]) -> Bool {
        guard let file = files.first else { return false }
        dropLog.debug("opening dropped \(file.name, privacy: .public)")
        open(file.url, displayName: file.name)
        return true
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
            dropLog.debug("importing \(name, privacy: .public)")
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Dropped-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let copy = directory.appendingPathComponent(name)
                try FileManager.default.copyItem(at: received.file, to: copy)
                return DroppedFile(url: copy, name: name)
            } catch {
                dropLog.error("import of \(name, privacy: .public) failed: \(error, privacy: .public)")
                throw error
            }
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
