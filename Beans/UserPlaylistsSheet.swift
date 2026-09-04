import SwiftUI

/// 用户自建歌单浏览：查看、播放全部、删除。
struct UserPlaylistsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @ObservedObject private var store = UserPlaylistStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var opened: UUID?

    var body: some View {
        BeansNavigationStack {
            Group {
                if store.playlists.isEmpty {
                    empty
                } else if let id = opened, let pl = store.playlists.first(where: { $0.id == id }) {
                    detail(pl)
                } else {
                    list
                }
            }
            .navigationTitle("我的歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("关闭") { dismiss() } }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundStyle(Color.beansComment)
            Text("还没有自建歌单")
                .font(BeansFont.appFont(14))
                .foregroundStyle(Color.beansComment)
            Text("在歌曲菜单里点“添加到歌单”即可创建")
                .font(BeansFont.appFont(12))
                .foregroundStyle(Color.beansComment.opacity(0.8))
        }
    }

    private var list: some View {
        List {
            ForEach(store.playlists) { pl in
                Button {
                    BeansHaptics.tap(); opened = pl.id
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note.list").foregroundStyle(Color.beansAmber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pl.name).font(BeansFont.appFont(15)).foregroundStyle(Color.beansLabel)
                            Text("\(pl.songs.count) 首").font(BeansFont.appFont(11)).foregroundStyle(Color.beansComment)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.beansComment.opacity(0.6))
                    }
                }
            }
            .onDelete { idx in
                idx.map { store.playlists[$0].id }.forEach(store.delete)
            }
        }
    }

    private func detail(_ pl: UserPlaylist) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { opened = nil } label: {
                    Label("返回", systemImage: "chevron.left")
                }
                Spacer()
                Button {
                    BeansHaptics.tap()
                    player.play(songs: pl.songs, startAt: 0)
                } label: {
                    Label("播放全部", systemImage: "play.fill")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            List {
                ForEach(pl.songs) { song in
                    SongCell(song: song)
                        .environmentObject(player)
                        .environmentObject(auth)
                }
                .onDelete { idx in
                    idx.map { pl.songs[$0].id }.forEach { store.remove(songID: $0, from: pl.id) }
                }
            }
        }
    }
}
