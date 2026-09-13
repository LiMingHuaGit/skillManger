import SwiftUI

struct NotchNotebookPane: View {
    @ObservedObject var store: NoteStore
    @ObservedObject var settingsStore: NotchWorkspaceSettings
    let imageStore: LocalImageStore
    @ObservedObject var fileShelfStore: FileShelfStore
    @ObservedObject var workspaceState: NotebookWorkspaceState
    let editorInteractionState: EditorInteractionState

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                TabPagerControl(
                    store: store,
                    editorInteractionState: editorInteractionState,
                    availableWidth: proxy.size.width
                )
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)

                MarkdownEditorPanel(
                    store: store,
                    settingsStore: settingsStore,
                    imageStore: imageStore,
                    editorInteractionState: editorInteractionState,
                    size: editorSize(in: proxy.size)
                )
                .frame(width: proxy.size.width, height: editorSize(in: proxy.size).height)
                .background(Color(white: 0.055))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if showsShelf {
                    FileShelfView(
                        store: fileShelfStore,
                        workspaceState: workspaceState,
                        size: CGSize(width: proxy.size.width, height: 78)
                    )
                    .frame(width: proxy.size.width, height: 78)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard !workspaceState.isDraggingShelfItem else { return false }
                workspaceState.isShelfDropTargeted = false
                return fileShelfStore.acceptDrop(urls)
            } isTargeted: { targeted in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    workspaceState.isShelfDropTargeted = targeted && !workspaceState.isDraggingShelfItem
                }
            }
            .onAppear {
                editorInteractionState.onSelectionChange = { [weak store] range in
                    guard let store else { return }
                    store.updateSelection(for: store.activeTabID, range: range)
                }
                editorInteractionState.restoreSelection(store.selectionRange(for: store.activeTabID))
            }
            .onChange(of: store.activeTabID) { _, tabID in
                editorInteractionState.restoreSelection(store.selectionRange(for: tabID), reveal: false)
            }
        }
    }

    private var showsShelf: Bool {
        workspaceState.isShelfDropTargeted || !fileShelfStore.items.isEmpty
    }

    private func editorSize(in size: CGSize) -> CGSize {
        let reservedHeight: CGFloat = showsShelf ? 122 : 36
        return CGSize(width: size.width, height: max(size.height - reservedHeight, 220))
    }
}

struct NotchFileShelfPane: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: FileShelfStore
    @ObservedObject var workspaceState: NotebookWorkspaceState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if store.items.isEmpty, !workspaceState.isShelfDropTargeted {
                    VStack(spacing: 10) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 28, weight: .light))
                        Text(locale.identifier.lowercased().hasPrefix("zh") ? "拖放文件到这里" : "Drop files here")
                            .font(.callout.weight(.semibold))
                        Text(locale.identifier.lowercased().hasPrefix("zh")
                             ? "最多暂存 100 个文件，不会移动或删除原文件"
                             : "Keep up to 100 references without moving the originals")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.42))
                    }
                    .foregroundStyle(.white.opacity(0.66))
                }

                FileShelfView(store: store, workspaceState: workspaceState, size: proxy.size)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
                .dropDestination(for: URL.self) { urls, _ in
                    workspaceState.isShelfDropTargeted = false
                    return store.acceptDrop(urls)
                } isTargeted: { targeted in
                    workspaceState.isShelfDropTargeted = targeted
                }
        }
    }
}
