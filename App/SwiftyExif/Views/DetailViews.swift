import SwiftUI
import SwiftyExifTool

struct TagDetailView: View {
    let row: TagRow

    var body: some View {
        Form {
            Section("Tag") {
                LabeledContent("Group", value: row.group.rawValue)
                LabeledContent("Name", value: row.name)
                LabeledContent("ID", value: row.idText ?? "–")
                LabeledContent("Known", value: row.isUnknown ? "No (no definition)" : "Yes")
            }
            if let stored = row.tag.stored {
                Section("Stored") {
                    LabeledContent("Field type", value: stored.fieldType.description)
                    LabeledContent("Count", value: String(stored.count))
                    Text(StoredValueText.describe(stored))
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
            }
            Section("Value (exiftool -n)") {
                Text(row.valueText).textSelection(.enabled)
            }
            Section("Display text (exiftool)") {
                Text(row.displayText).textSelection(.enabled)
            }
            if let location = row.tag.location {
                Section("Location") {
                    LabeledContent("Entry offset", value: offset(location.entryOffset))
                    LabeledContent("Value offset", value: offset(location.valueOffset))
                    LabeledContent("Value length", value: "\(location.length) bytes")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func offset(_ value: Int) -> String { "\(value) (0x\(String(value, radix: 16, uppercase: true)))" }
}

struct SummaryView: View {
    let file: InspectedFile

    var body: some View {
        Form {
            LabeledContent("File", value: file.displayName)
            LabeledContent("Size", value: file.fileSizeText)
            LabeledContent("File type", value: file.fileTypeText)
            LabeledContent("Byte order", value: file.byteOrderText)
            LabeledContent("Tags", value: String(file.tagCount))
            LabeledContent("Directories", value: String(file.directoryCount))
            LabeledContent("Warnings", value: String(file.warningCount))
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
    }
}

struct DirectoriesView: View {
    let directories: [Directory]

    var body: some View {
        if directories.isEmpty {
            ContentUnavailableView("No Directories", systemImage: "square.stack.3d.up.slash")
        } else {
            List(Array(directories.enumerated()), id: \.offset) { _, directory in
                VStack(alignment: .leading, spacing: 2) {
                    Text(directory.group.rawValue).font(.headline)
                    Text("Offset \(directory.offset) · \(directory.entryCount) entries · next IFD \(directory.nextIFDOffset.map(String.init) ?? "–")")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .textSelection(.enabled)
            }
        }
    }
}

struct WarningsView: View {
    let warnings: [ReadWarning]

    var body: some View {
        if warnings.isEmpty {
            ContentUnavailableView("No Warnings", systemImage: "checkmark.circle")
        } else {
            List(Array(warnings.enumerated()), id: \.offset) { _, warning in
                VStack(alignment: .leading, spacing: 2) {
                    Text(warning.message)
                    Text([warning.group.map { "Group \($0)" }, warning.offset.map { "offset \($0)" }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .textSelection(.enabled)
            }
        }
    }
}
