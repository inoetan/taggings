import AppKit
import Foundation

struct TaggedFile: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    var displayName: String { url.lastPathComponent }
    var isDirectory: Bool
    var tagNames: [String]  // raw names, without color suffix

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    static func == (lhs: TaggedFile, rhs: TaggedFile) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
