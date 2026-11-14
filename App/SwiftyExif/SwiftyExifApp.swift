import SwiftUI

@main
struct SwiftyExifApp: App {
    @State private var model = InspectorModel()
    @State private var isImporting = false

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, isImporting: $isImporting)
                .onOpenURL { url in model.open(url) }
                .task { openFromLaunchArguments() }
        }
        // Room for the sidebar, all table columns and the details inspector.
        .defaultSize(width: 1280, height: 760)
        // One window: files opened from Finder replace the shown file.
        .handlesExternalEvents(matching: ["*"])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { isImporting = true }
                    .keyboardShortcut("o")
            }
        }
    }

    /// Debug builds only: `-SwiftyExifOpen <path>` opens a file at launch and
    /// `-SwiftyExifSearch <text>` sets the search text, for scripted app checks.
    private func openFromLaunchArguments() {
        #if DEBUG
        let defaults = UserDefaults.standard
        guard model.file == nil, let path = defaults.string(forKey: "SwiftyExifOpen") else { return }
        model.open(URL(fileURLWithPath: path))
        if let search = defaults.string(forKey: "SwiftyExifSearch") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                model.query.searchText = search
            }
        }
        #endif
    }
}
