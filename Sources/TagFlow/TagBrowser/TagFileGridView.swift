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
                EmptyStateView(
                    icon: "tag.slash",
                    title: "ファイルがありません",
                    message: "「\(tag.name)」タグが付いたファイルがありません"
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
        // macOS 13 compatible onChange (closure receives new value)
        .onChange(of: tag.id) { _ in startQuery() }
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
        }
    }
}

/// macOS 13 compatible empty state placeholder (ContentUnavailableView requires macOS 14)
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
