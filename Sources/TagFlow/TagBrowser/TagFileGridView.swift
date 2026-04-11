import SwiftUI
import AppKit

// MARK: - Sort option

private enum SortOption: String, CaseIterable, Identifiable {
    case nameAscending  = "名前"
    case dateDescending = "更新日"
    case kindAscending  = "種類"
    var id: Self { self }
}

// MARK: - Main view

struct TagFileGridView: View {
    let tag: Tag
    @StateObject private var queryService = MetadataQueryService()
    @State private var files: [TaggedFile] = []
    @State private var isLoading = true
    @State private var isListView = false
    /// URLs of currently selected files (URL == TaggedFile.id).
    @State private var selectedFileIDs: Set<URL> = []
    /// Last item tapped without Shift — anchor for range selection.
    @State private var selectionAnchorID: URL? = nil
    @State private var sortOption: SortOption = .nameAscending

    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 100))]

    // MARK: - Sorted files

    private var sortedFiles: [TaggedFile] {
        switch sortOption {
        case .nameAscending:
            return files.sorted {
                $0.displayName.localizedCompare($1.displayName) == .orderedAscending
            }
        case .dateDescending:
            return files.sorted {
                ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast)
            }
        case .kindAscending:
            return files.sorted {
                $0.url.pathExtension.localizedCompare($1.url.pathExtension) == .orderedAscending
            }
        }
    }

    // MARK: - Body

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
                // Tag-removal button — enabled when anything is selected
                Button(action: removeTagFromSelected) {
                    Label("タグを解除", systemImage: "tag.slash")
                }
                .disabled(selectedFileIDs.isEmpty)
                .help("選択したファイルから「\(tag.name)」タグを解除")

                Divider()

                // Sort picker
                Picker("並び順", selection: $sortOption) {
                    ForEach(SortOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .help("並び順")
                .frame(width: 88)

                Divider()

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
        // Hidden ⌘+A button for "select all" — mirrors Finder
        .background(
            Button("") {
                selectedFileIDs = Set(sortedFiles.map { $0.url })
                selectionAnchorID = sortedFiles.last?.url
            }
            .keyboardShortcut("a", modifiers: .command)
            .hidden()
        )
        // Escape clears selection — mirrors Finder
        .onExitCommand { selectedFileIDs.removeAll(); selectionAnchorID = nil }
        .onAppear { startQuery() }
        .onDisappear { queryService.stopQuery() }
        .onChange(of: tag.id) { _ in
            selectedFileIDs.removeAll()
            selectionAnchorID = nil
            startQuery()
        }
        .onChange(of: sortOption) { _ in
            // Anchor index may have shifted after re-sort; clear to avoid wrong range.
            selectionAnchorID = nil
        }
    }

    // MARK: - Grid view

    private var fileGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(sortedFiles) { file in
                    FileGridCell(file: file, isSelected: selectedFileIDs.contains(file.url))
                        // Double-click: open with default app — same as Finder
                        .onTapGesture(count: 2) {
                            NSWorkspace.shared.open(file.url)
                        }
                        // Single-click: Finder-style selection with modifier support
                        .onTapGesture(count: 1) {
                            handleGridTap(file: file)
                        }
                        .onDrag {
                            NSItemProvider(object: file.url as NSURL)
                        }
                        .contextMenu {
                            Button("Finderで表示") {
                                NSWorkspace.shared.activateFileViewerSelecting([file.url])
                            }
                            Divider()
                            Button("タグを解除", role: .destructive) {
                                try? XattrService.removeTag(tag, from: file.url)
                                startQuery()
                            }
                        }
                }
            }
            .padding()
            // Tapping empty space between cells deselects all.
            // File cells intercept taps at their own hit-target first, so this
            // background handler fires only for taps on empty areas.
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFileIDs.removeAll()
                        selectionAnchorID = nil
                    }
            )
        }
    }

    // MARK: - Grid selection (Finder semantics)

    private func handleGridTap(file: TaggedFile) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            // ⌘+click: toggle item in/out of selection
            if selectedFileIDs.contains(file.url) {
                selectedFileIDs.remove(file.url)
            } else {
                selectedFileIDs.insert(file.url)
            }
            selectionAnchorID = file.url
        } else if flags.contains(.shift),
                  let anchor = selectionAnchorID,
                  let ai = sortedFiles.firstIndex(where: { $0.url == anchor }),
                  let ci = sortedFiles.firstIndex(where: { $0.url == file.url }) {
            // Shift+click: extend selection from anchor to this item
            let lo = min(ai, ci), hi = max(ai, ci)
            selectedFileIDs = Set(sortedFiles[lo...hi].map { $0.url })
            // Anchor stays fixed — mirrors Finder range-select behavior
        } else {
            // Plain click: select only this item, deselect everything else
            selectedFileIDs = [file.url]
            selectionAnchorID = file.url
        }
    }

    // MARK: - List view

    private var fileList: some View {
        List(sortedFiles, selection: $selectedFileIDs) { file in
            FileListRow(file: file)
                // Double-click to open; simultaneousGesture lets List's native
                // single-click selection continue to work normally.
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        NSWorkspace.shared.open(file.url)
                    }
                )
                .onDrag {
                    NSItemProvider(object: file.url as NSURL)
                }
                .contextMenu {
                    Button("Finderで表示") {
                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                    }
                    Divider()
                    Button("タグを解除", role: .destructive) {
                        try? XattrService.removeTag(tag, from: file.url)
                        startQuery()
                    }
                }
        }
        .listStyle(.inset)
        // Delete key removes the tag from selected files
        .onDeleteCommand { removeTagFromSelected() }
    }

    // MARK: - Actions

    private func removeTagFromSelected() {
        let urlsToProcess = files
            .filter { selectedFileIDs.contains($0.url) }
            .map { $0.url }
        for url in urlsToProcess {
            try? XattrService.removeTag(tag, from: url)
        }
        selectedFileIDs.removeAll()
        selectionAnchorID = nil
        startQuery()
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
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: file.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, Color.accentColor)
                        .font(.system(size: 16))
                        .offset(x: 6, y: -6)
                }
            }
            Text(file.displayName)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
        }
        .frame(width: 88)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
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
