import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Texts copied from the tag list.
enum CopyText {
    static func value(_ row: TagRow) -> String { row.valueText }
    static func display(_ row: TagRow) -> String { row.displayText }
    /// `Group:Name<TAB>value<TAB>display text`.
    static func row(_ row: TagRow) -> String { "\(row.qualifiedName)\t\(row.valueText)\t\(row.displayText)" }
    static func rows(_ rows: [TagRow]) -> String { rows.map(row).joined(separator: "\n") }
}

/// Where copied text goes; replaced by a recording pasteboard in tests.
@MainActor
protocol Pasteboard {
    func setString(_ string: String)
}

/// The system pasteboard.
@MainActor
struct SystemPasteboard: Pasteboard {
    func setString(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}
