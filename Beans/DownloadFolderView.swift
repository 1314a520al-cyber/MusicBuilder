import SwiftUI

/// 下载管理：文件夹列表 + 已下载歌曲
struct DownloadFolderView: View {
    @ObservedObject private var store = DownloadStore.shared
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var editingFolder: DownloadFolder?
    @State private var selectedFolderID: UUID?

    var body: some View {
        BeansNavigationStack {
            Group {
                if let folderID = selectedFolderID, let folder = store.folders.first(where: { $0.id == folderID }) {
                    folderDetail(folder)
                } else {
                    folderList
                }
            }
            .navigationTitle(selectedFolderID == nil ? "下载管理" : (store.folders.first { $0.id == selectedFolderID }?.name ?? ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedFolderID != nil ? "返回" : "关闭") {
                        if selectedFolderID != nil { selectedFolderID = nil } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreateFolder = true } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .opacity(selectedFolderID == nil ? 1 : 0)
                    .disabled(selectedFolderID != nil)
                }
            }
            .alert("新建文件夹", isPresented: $showCreateFolder) {
                TextField("文件夹名称", text: $newFolderName)
                Button("取消", role: .cancel) { newFolderName = "" }
                Button("创建") {
                    store.createFolder(named: newFolderName)
                    newFolderName = ""
                }
            }
            .alert("重命名文件夹", isPresented: Binding(
                get: { editingFolder != nil },
                set: { if !$0 { editingFolder = nil } }
            )) {
                TextField("新名称", text: Binding(
                    get: { editingFolder?.name ?? "" },
                    set: { if var f = editingFolder { f.name = $0; editingFolder = f } }
                ))
                Button("取消", role: .cancel) {}
                Button("保存") {
                    if let f = editingFolder { store.renameFolder(f.id, to: f.name) }
                    editingFolder = nil
                }
            }
        }
    }

    private var folderList: some View {
        List {
            ForEach(store.folders) { folder in
                Button {
                    BeansHaptics.tap()
                    selectedFolderID = folder.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 44, height: 44)
                            .background(Color.beansAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(folder.name)
                                .font(BeansFont.appFont(15, .semibold))
                                .foregroundStyle(Color.beansLabel)
                            Text("\(folder.songCount) 首 · \(DownloadStore.formatSize(folder.totalSize))")
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.beansComment.opacity(0.6))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { editingFolder = folder } label: { Label("重命名", systemImage: "pencil") }
                    Button(role: .destructive) { store.deleteFolder(folder.id) } label: { Label("删除", systemImage: "trash") }
                }
            }
            if store.folders.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.beansComment)
                        Text("还没有下载文件夹")
                            .font(BeansFont.appFont(14))
                            .foregroundStyle(Color.beansComment)
                        Text("点击右上角 + 创建文件夹")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
    }

    private func folderDetail(_ folder: DownloadFolder) -> some View {
        let songs = store.songs(in: folder.id)
        return List {
            if songs.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.beansComment)
                        Text("这个文件夹还没有歌曲")
                            .font(BeansFont.appFont(14))
                            .foregroundStyle(Color.beansComment)
                        Text("下载时选择此文件夹即可")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                ForEach(songs) { ds in
                    HStack(spacing: 12) {
                        CoverImage(url: URL(string: ds.coverURL), size: 44, cornerRadius: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ds.name)
                                .font(BeansFont.appFont(14))
                                .foregroundStyle(Color.beansLabel)
                                .lineLimit(1)
                            Text("\(ds.artist) · \(ds.quality) · \(DownloadStore.formatSize(ds.fileSize))")
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            if let url = ds.fileURL {
                                player.playLocalFile(url: url, title: ds.name, artist: ds.artist)
                            }
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.beansAmber)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button {
                            if let url = ds.fileURL {
                                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.rootViewController?.present(av, animated: true)
                            }
                        } label: { Label("分享", systemImage: "square.and.arrow.up") }
                        Button(role: .destructive) { store.deleteDownloadedSong(ds.id) } label: { Label("删除", systemImage: "trash") }
                    }
                }
                .onDelete { idx in
                    idx.map { songs[$0].id }.forEach(store.deleteDownloadedSong)
                }
            }
        }
    }
}
