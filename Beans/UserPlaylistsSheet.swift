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
            // 顶部栏
            HStack(spacing: 10) {
                Button { opened = nil } label: {
                    Label("返回", systemImage: "chevron.left")
                }
                Spacer()
                // 排序按钮
                Menu {
                    ForEach(UserPlaylist.SortOption.allCases) { option in
                        Button {
                            sortOption = option
                        } label: {
                            if sortOption == option {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 16))
                }
                Button {
                    withAnimation { showSearch.toggle() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                }
                Button {
                    BeansHaptics.tap()
                    player.play(songs: displayedSongs(for: pl), startAt: 0)
                } label: {
                    Label("播放全部", systemImage: "play.fill")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            
            // 搜索框
            if showSearch {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索歌单内歌曲", text: $searchText)
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // 歌单信息
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pl.name)
                        .font(.headline)
                    Text("\(displayedSongs(for: pl).count) 首\(pl.note.isEmpty ? "" : " · \(pl.note)")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            List {
                ForEach(displayedSongs(for: pl)) { song in
                    SongCell(song: song)
                        .environmentObject(player)
                        .environmentObject(auth)
                }
                .onDelete { idx in
                    let songs = displayedSongs(for: pl)
                    idx.map { songs[$0].id }.forEach { store.remove(songID: $0, from: pl.id) }
                }
            }
        }
    }
    
    @State private var sortOption: UserPlaylist.SortOption = .byAdded
    @State private var showSearch = false
    @State private var searchText = ""
    
    private func displayedSongs(for pl: UserPlaylist) -> [Song] {
        var songs = pl.sorted(by: sortOption)
        if !searchText.isEmpty {
            songs = pl.search(searchText)
            if sortOption != .byAdded {
                songs = songs.sorted { lhs, rhs in
                    switch sortOption {
                    case .byName: return lhs.name < rhs.name
                    case .byArtist: return lhs.artists < rhs.artists
                    case .byAlbum: return lhs.album < rhs.album
                    case .byDuration: return lhs.duration < rhs.duration
                    default: return true
                    }
                }
            }
        }
        return songs
    }
}
