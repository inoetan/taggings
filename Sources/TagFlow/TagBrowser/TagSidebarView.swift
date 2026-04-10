import SwiftUI

struct TagSidebarView: View {
    @ObservedObject var tagStore: TagStore
    @Binding var selectedTag: Tag?
    @State private var newTagName: String = ""
    @State private var isAddingTag = false

    var body: some View {
        List(selection: $selectedTag) {
            Section("タグ") {
                ForEach(tagStore.tags) { tag in
                    TagSidebarRow(tag: tag)
                        .tag(tag)
                        .contextMenu {
                            Menu("カラー") {
                                ForEach(Tag.TagColor.allCases, id: \.self) { color in
                                    Button(action: { tagStore.updateColor(color, for: tag) }) {
                                        if tag.color == color {
                                            Label(color.displayName, systemImage: "checkmark")
                                        } else {
                                            Text(color.displayName)
                                        }
                                    }
                                }
                            }
                            Divider()
                            Button("削除", role: .destructive) {
                                if selectedTag?.id == tag.id { selectedTag = nil }
                                tagStore.deleteTag(tag)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            addTagButton
        }
    }

    @ViewBuilder
    private var addTagButton: some View {
        VStack(spacing: 0) {
            Divider()
            if isAddingTag {
                HStack {
                    TextField("タグ名", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(commitNewTag)
                    Button("追加", action: commitNewTag)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button { isAddingTag = false; newTagName = "" } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            } else {
                Button {
                    isAddingTag = true
                } label: {
                    Label("新しいタグ", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .background(.bar)
    }

    private func commitNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { tagStore.addTag(name: name) }
        isAddingTag = false
        newTagName = ""
    }
}

private struct TagSidebarRow: View {
    let tag: Tag

    var body: some View {
        Label {
            Text(tag.name)
        } icon: {
            Circle()
                .fill(Color(nsColor: tag.color.nsColor))
                .frame(width: 12, height: 12)
        }
    }
}
