import SwiftUI

/// Shared navigation state for the tag browser.
/// Held by TagBrowserWindowController so the status bar can drive the
/// selection without recreating the window.
final class TagBrowserNavigation: ObservableObject {
    @Published var selectedTag: Tag?
}

struct TagBrowserView: View {
    @ObservedObject var tagStore: TagStore
    @ObservedObject var navigation: TagBrowserNavigation

    var body: some View {
        NavigationSplitView {
            TagSidebarView(tagStore: tagStore, selectedTag: $navigation.selectedTag)
                .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
        } detail: {
            if let tag = navigation.selectedTag {
                TagFileGridView(tag: tag)
            } else {
                EmptyStateView(
                    icon: "tag",
                    title: "タグを選択",
                    message: "左のサイドバーからタグを選んでください"
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
