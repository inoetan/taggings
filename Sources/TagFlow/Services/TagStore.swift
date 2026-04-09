import Foundation
import Combine

/// Manages the list of known tags. Tag definitions are persisted in Application Support.
/// Tag-to-file mapping is stored exclusively in xattr — no separate index.
final class TagStore: ObservableObject {
    static let shared = TagStore()

    @Published private(set) var tags: [Tag] = []

    private let saveURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("TagFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tags.json")
    }()

    private init() {
        load()
    }

    // MARK: - CRUD

    func addTag(name: String, color: Tag.TagColor = .none) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(where: { $0.name == trimmed }) else { return }
        tags.append(Tag(name: trimmed, color: color))
        save()
    }

    func renameTag(_ tag: Tag, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(where: { $0.name == trimmed && $0.id != tag.id }) else { return }
        guard let idx = tags.firstIndex(where: { $0.id == tag.id }) else { return }
        tags[idx].name = trimmed
        save()
    }

    func updateColor(_ color: Tag.TagColor, for tag: Tag) {
        guard let idx = tags.firstIndex(where: { $0.id == tag.id }) else { return }
        tags[idx].color = color
        save()
    }

    func deleteTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
        save()
    }

    func tag(named name: String) -> Tag? {
        tags.first { $0.name == name }
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(tags)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("[TagStore] Save failed: \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([Tag].self, from: data) else {
            return
        }
        tags = decoded
    }
}
