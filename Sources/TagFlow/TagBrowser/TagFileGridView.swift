import SwiftUI
import AppKit

struct TagFileGridView: View {
    let tag: Tag
    @StateObject private var queryService = MetadataQueryService()
    @State private var files: [TaggedFile] = []
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 100))]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("検索中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if files.isEmpty {
                ContentUnavailableView(
                    "ファイルがありません",
                    systemImage: "tag.slash",
                    description: Text("「\(tag.name)」タグが付いたファイルがありません")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(files) { file in
                            FileCell(file: file)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(tag.name)
        .toolbar {
            ToolbarItem {
                Button {
                    startQuery()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("更新")
            }
        }
        .onAppear { startQuery() }
        .onDisappear { queryService.stopQuery() }
        .onChange(of: tag.id) { startQuery() }
    }

    private func startQuery() {
        isLoading = true
        queryService.startQuery(forTagName: tag.name) { urls in
            self.files = urls.map { url in
                TaggedFile(
                    url: url,
                    isDirectory: url.hasDirectoryPath,
                    tagNames: (try? XattrService.readTagNames(from: url)) ?? []
                )
            }
            self.isLoading = false
        }
    }
}

private struct FileCell: View {
    let file: TaggedFile

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: file.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
            Text(file.displayName)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
        }
        .frame(width: 88)
        .padding(6)
        .contentShape(Rectangle())
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .contextMenu {
            Button("Finderで表示") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
            Button("タグを管理…") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
        }
    }
}
