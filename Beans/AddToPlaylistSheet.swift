import SwiftUI
struct AddToPlaylistSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @ObservedObject private var localStore = UserPlaylistStore.shared
    @Environment(\.dismiss) private var dismiss
    let song: Song
    @State private var newName = ""
    @State private var showCreateField = false
    @State private var message: String?
    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            List {
                // 本地歌单：不登录也能用，任何音源的歌曲都可加入
                Section("本地歌单") {
                    if localStore.playlists.isEmpty {
                        Text("还没有本地歌单，下方可新建")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                    }
                    ForEach(localStore.playlists) { pl in
                        Button {
                            let added = localStore.add(song: song, to: pl.id)
                            BeansHaptics.tap()
                            if added { dismiss() } else { message = "已在「\(pl.name)」中" }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "music.note.list")
                                    .foregroundStyle(Color.beansAmber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pl.name)
                                        .font(BeansFont.appFont(15))
                                        .foregroundStyle(Color.beansLabel)
                                    Text("\(pl.songs.count) 首 · 本地")
                                        .font(BeansFont.appFont(11))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer()
                            }
                        }
                    }
                    if showCreateField {
                        VStack(spacing: 8) {
                            TextField("歌单名称", text: $newName)
                                .submitLabel(.done)
                            Button {
                                createLocalAndAdd()
                            } label: {
                                Text("创建并添加")
                                    .font(BeansFont.appFont(15, .semibold))
                                    .foregroundStyle(Color.beansAmber)
                            }
                        }
                    } else {
                        Button {
                            showCreateField = true
                        } label: {
                            Label("新建本地歌单", systemImage: "plus.circle")
                        }
                    }
                }

                // 云端歌单：网易云登录后可用
                if auth.isLoggedIn && !auth.playlists.isEmpty {
                    Section("网易云歌单") {
                        ForEach(auth.playlists) { playlist in
                            Button {
                                Task { await add(to: playlist) }
                            } label: {
                                HStack(spacing: 12) {
                                    CoverImage(url: playlist.coverURL, size: 38, cornerRadius: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(playlist.name)
                                            .font(BeansFont.appFont(15))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text("\(playlist.trackCount) 首 · 云端")
                                            .font(BeansFont.appFont(11))
                                            .foregroundStyle(Color.beansComment)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                if let message {
                    Section {
                        Text(message)
                            .font(BeansFont.appFont(13))
                            .foregroundStyle(Color.beansSage)
                    }
                }
            }
            .navigationTitle("添加到歌单")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private func createLocalAndAdd() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let pl = localStore.create(named: name)
        localStore.add(song: song, to: pl.id)
        dismiss()
    }
    private func add(to playlist: Playlist) async {
        let ok = (try? await NetEaseAPI.shared.addToPlaylist(playlistID: playlist.id, songIDs: [song.id])) ?? false
        if ok {
            dismiss()
        } else {
            message = "云端添加失败，可改用上方本地歌单"
        }
    }
}
