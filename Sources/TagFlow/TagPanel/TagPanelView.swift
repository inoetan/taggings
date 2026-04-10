import SwiftUI
import AppKit

struct TagPanelView: View {
    let edge: ScreenEdge
    let draggedURLs: [URL]
    @ObservedObject var tagStore: TagStore
    let coordinator: DragCoordinator

    @State private var hoveredTagID: UUID? = nil
    @State private var dropTargetTagID: UUID? = nil
    @State private var newTagName: String = ""
    @State private var isAddingTag = false

    var body: some View {
        ZStack {
            // Frosted glass background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .cornerRadius(16)

            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().padding(.horizontal, 12)
                tagList
                Divider().padding(.horizontal, 12)
                addTagSection
            }
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 16)
    }

    private var header: some View {
        HStack {
            Image(systemName: "tag.fill")
                .foregroundStyle(.secondary)
            Text("タグを選択")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(draggedURLs.count)件")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var tagList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(tagStore.tags) { tag in
                    TagRowView(tag: tag,
                               isHovered: hoveredTagID == tag.id || dropTargetTagID == tag.id)
                        .onHover { hovering in
                            hoveredTagID = hovering ? tag.id : nil
                        }
                        .onDrop(of: [.fileURL], isTargeted: Binding(
                            get: { dropTargetTagID == tag.id },
                            set: { active in
                                if active {
                                    dropTargetTagID = tag.id
                                } else if dropTargetTagID == tag.id {
                                    dropTargetTagID = nil
                                }
                            }
                        )) { providers in
                            handleDrop(tag: tag, providers: providers)
                            return true
                        }
                        .onTapGesture {
                            coordinator.applyTag(tag, to: draggedURLs)
                            coordinator.dragDidEnd(edge)
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 400)
    }

    /// Extract file URLs from the drop providers, then apply the tag.
    ///
    /// Background: `draggingEntered` on the strip fires AFTER `mouseEntered`,
    /// so the panel opens with `draggedURLs = []`. The actual dragged files
    /// arrive here via the `NSItemProvider` array. We load them async and fall
    /// back to `draggedURLs` only when providers yield nothing.
    private func handleDrop(tag: Tag, providers: [NSItemProvider]) {
        print("[Panel] handleDrop tag=\(tag.name) providers=\(providers.count) draggedURLs=\(draggedURLs.count)")

        let capturedURLs = draggedURLs

        guard !providers.isEmpty else {
            // Tap-gesture path: providers is empty, use whatever was set when panel opened.
            coordinator.applyTag(tag, to: capturedURLs)
            coordinator.dragDidEnd(edge)
            return
        }

        var loaded: [URL] = []
        let lock = NSLock()
        let group = DispatchGroup()

        for provider in providers {
            print("[Panel] provider UTIs: \(provider.registeredTypeIdentifiers)")
            guard provider.hasItemConformingToTypeIdentifier("public.file-url") else { continue }
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                defer { group.leave() }
                if let error = error {
                    print("[Panel] loadItem error: \(error)")
                    return
                }
                let resolved: URL?
                switch item {
                case let url as URL:
                    resolved = url
                case let nsURL as NSURL:
                    resolved = nsURL as URL
                case let data as Data:
                    resolved = URL(dataRepresentation: data, relativeTo: nil)
                default:
                    print("[Panel] unexpected item type: \(type(of: item))")
                    resolved = nil
                }
                if let url = resolved {
                    lock.lock()
                    loaded.append(url)
                    lock.unlock()
                }
            }
        }

        // Wait on a background thread so we don't block the main run loop.
        // `loadItem` completion handlers run on a private queue (not main).
        DispatchQueue.global(qos: .userInitiated).async {
            group.wait()
            print("[Panel] loaded \(loaded.count) URLs from providers, fallback draggedURLs=\(capturedURLs.count)")
            let urlsToTag = loaded.isEmpty ? capturedURLs : loaded
            DispatchQueue.main.async {
                coordinator.applyTag(tag, to: urlsToTag)
                coordinator.dragDidEnd(edge)
            }
        }
    }

    private var addTagSection: some View {
        Group {
            if isAddingTag {
                HStack {
                    TextField("タグ名", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitNewTag() }
                    Button("追加") { commitNewTag() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button(action: { isAddingTag = false; newTagName = "" }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
                Button {
                    isAddingTag = true
                } label: {
                    Label("新しいタグ", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func commitNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            tagStore.addTag(name: name)
            if let newTag = tagStore.tag(named: name) {
                coordinator.applyTag(newTag, to: draggedURLs)
            }
        }
        isAddingTag = false
        newTagName = ""
        coordinator.dragDidEnd(edge)
    }
}

struct TagRowView: View {
    let tag: Tag
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(nsColor: tag.color.nsColor))
                .frame(width: 12, height: 12)
            Text(tag.name)
                .font(.system(size: 15))
            Spacer()
            if isHovered {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .contentShape(Rectangle())
    }
}

/// NSVisualEffectView wrapper for SwiftUI
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
