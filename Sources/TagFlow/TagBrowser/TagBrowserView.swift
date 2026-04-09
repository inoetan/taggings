import SwiftUI

struct TagBrowserView: View {
    @ObservedObject var tagStore: TagStore
    @State private var selectedTag: Tag? = nil

    var body: some View {
        NavigationSplitView {
            TagSidebarView(tagStore: tagStore, selectedTag: $selectedTag)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
        } detail: {
            if let tag = selectedTag {
                TagFileGridView(tag: tag)
            } else {
                ContentUnavailableView(
                    "タグを選択",
                    systemImage: "tag",
                    description: Text("左のサイドバーからタグを選んでください")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
