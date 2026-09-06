import SwiftUI
import UniformTypeIdentifiers

struct QueueView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAddToPlaylist = false
    @State private var showComments = false
    @State private var showMoreActions = false
    @State private var actionSong: Song?
    @State private var exportURL: URL?
    @State private var showExportPicker = false
    @State private var downloadMessage = ""

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            Group {
                if player.queue.isEmpty {
                    EmptyStateView(icon: "music.note.list", text: "播放队列为空")
                } else {
                    List {
                        Section("接下来 (\(player.queue.count) 首)") {
                            ForEach(Array(player.queue.enumerated()), id: \.element.identityKey) { index, song in
                                row(song, index: index)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                            .onDelete { offsets in
                                let indices = offsets.map { $0 }
                                for index in indices.sorted(by: >) where player.queue.indices.contains(index) {
                                    player.removeFromQueue(at: index)
                                }
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                    .background(LinearGradient.beansBackdrop)
                }
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            player.clearQueue()
                        } label: {
                            Label("清空队列", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !downloadMessage.isEmpty {
                    Text(downloadMessage)
                        .font(.system(size: 13))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showExportPicker) {
                if let url = exportURL {
                    DocumentExportPicker(url: url)
                }
            }
            .sheet(isPresented: $showAddToPlaylist) {
                if let song = actionSong {
                    AddToPlaylistSheet(song: song).environmentObject(auth)
                }
            }
            .sheet(isPresented: $showComments) {
                if let song = actionSong {
                    CommentsSheet(song: song)
                }
            }
            .actionSheet(isPresented: $showMoreActions) {
                ActionSheet(title: Text(actionSong?.name ?? ""), buttons: [
                    .default(Text("查看歌手")) {},
                    .default(Text("查看专辑")) {},
                    .default(Text("分享歌曲")) {},
                    .default(Text("设为铃声")) {},
                    .cancel()
                ])
            }
        }
        .animation(.easeInOut(duration: 0.2), value: downloadMessage)
    }

    @ViewBuilder
    private func row(_ song: Song, index: Int) -> some View {
        let isCurrent = index == player.currentIndex
        HStack(spacing: 12) {
            CoverImage(url: song.coverURL, size: 42, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(BeansFont.appFont(15, isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                Text(song.artists)
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            if isCurrent {
                if player.isPlaying {
                    NowPlayingIndicator()
                } else {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansAmber)
                }
            } else {
                Text(song.formattedDuration)
                    .font(BeansFont.appFont(12, .regular, .monospaced))
                    .foregroundStyle(Color.beansComment)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background {
                        BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .onTapGesture {
            if player.queue.indices.contains(index) {
                player.playQueueIndex(index)
            }
        }
        .contextMenu {
            Button {
                Task { await favorites.toggle(song) }
            } label: {
                Label(favorites.isLiked(song) ? "取消收藏" : "收藏", systemImage: favorites.isLiked(song) ? "heart.fill" : "heart")
            }
            Button {
                actionSong = song
                showAddToPlaylist = true
            } label: {
                Label("添加到歌单", systemImage: "text.badge.plus")
            }
            Button {
                actionSong = song
                showComments = true
            } label: {
                Label("评论", systemImage: "text.bubble")
            }
            Button {
                downloadSong(song)
            } label: {
                Label("下载歌曲", systemImage: "square.and.arrow.down")
            }
            Divider()
            Button {
                actionSong = song
                showMoreActions = true
            } label: {
                Label("更多", systemImage: "ellipsis.circle")
            }
        } preview: {
            QueueRowPreview(song: song)
        }
    }

    private func downloadSong(_ song: Song) {
        downloadMessage = "正在下载..."
        Task {
            let result = await DownloadManager.shared.download(song: song, quality: .high)
            switch result {
            case .success(let dl):
                exportURL = dl.url
                showExportPicker = true
                downloadMessage = "下载完成，请选择保存位置"
            case .failure(let err):
                downloadMessage = "下载失败：\(err.localizedDescription)"
            }
        }
    }
}

struct QueueRowPreview: View {
    let song: Song
    var body: some View {
        HStack(spacing: 10) {
            CoverImage(url: song.coverURL, size: 50, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                Text(song.artists).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .frame(width: 300)
        .background(Color(.systemBackground))
    }
}

// 文件导出选择器
struct DocumentExportPicker: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
