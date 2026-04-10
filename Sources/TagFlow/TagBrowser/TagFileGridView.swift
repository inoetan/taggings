import SwiftUI
import AppKit

struct TagFileGridView: View {
    let tag: Tag
    @StateObject private var queryService = MetadataQueryService()
    @State private var files: [TaggedFile] = []
    @State private var isLoading = true
    @State private var isListView = false

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
            } else if isListView {
                fileList
            } else {
                fileGrid
            }
        }
        .navigationTitle(tag.name)
        .toolbar {
            ToolbarItemGroup {
                // Grid / list toggle
                Picker("表示切替", selection: $isListView) {
                    Image(systemName: "square.grid.2x2").tag(false)
                    Image(systemName: "list.bullet").tag(true)
                }
                .pickerStyle(.segmented)
                .help("グリッド／リスト表示の切替")

                Button { startQuery() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("更新")
            }
        }
        .onAppear { startQuery() }
        .onDisappear { queryService.stopQuery() }
        .onChange(of: tag.id) { _ in startQuery() }
    }

    // MARK: - Grid view

    private var fileGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(files) { file in
                    FileGridCell(file: file)
                }
            }
            .padding()
        }
    }

    // MARK: - List view

    private var fileList: some View {
        List(files) { file in
            FileListRow(file: file)
                .onDrag {
                    NSItemProvider(object: file.url as NSURL)
                }
                .contextMenu {
                    Button("Finderで表示") {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    }
                }
        }
        .listStyle(.inset)
    }

    // MARK: - Data

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

// MARK: - Grid cell

private struct FileGridCell: View {
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

// MARK: - List row

private struct FileListRow: View {
    let file: TaggedFile

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: file.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(file.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 16)

            if let date = file.modificationDate {
                Text(Self.dateFormatter.string(from: date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Empty state

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
