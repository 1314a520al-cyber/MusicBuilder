import SwiftUI

/// 从付费音乐源同步下来的歌单详情：直接使用歌曲携带的直链播放。
struct SyncedPlaylistView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    let playlist: SyncedPlaylist
    @State private var searchText = ""
    private var tracks: [Song] { playlist.songs }
    private var filteredTracks: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return tracks }
        return tracks.filter {
            $0.name.lowercased().contains(kw) || $0.artists.lowercased().contains(kw)
        }
    }
    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                if tracks.isEmpty {
                    EmptyStateView(icon: "music.note.list", text: "该歌单暂无歌曲")
                } else {
                    List {
                        Section {
                            HStack(spacing: 12) {
                                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: 0)
                                }
                                GlassButton(title: "随机播放", systemName: "shuffle") {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: Int.random(in: 0..<filteredTracks.count))
                                }
                            }
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 8)
                        }
                        Section {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: filteredTracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                }
            }
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索歌单内歌曲")
        }
    }
}
