import Foundation
import SwiftUI

// MARK: - 批量操作管理器

final class BatchActionManager: ObservableObject {
    static let shared = BatchActionManager()
    
    @Published var selectionMode = false
    @Published var selectedSongs: Set<String> = []
    @Published var showAddToPlaylist = false
    @Published var showDownload = false
    
    private init() {}
    
    var selectedCount: Int { selectedSongs.count }
    
    func toggleSelect(_ identityKey: String) {
        if selectedSongs.contains(identityKey) {
            selectedSongs.remove(identityKey)
        } else {
            selectedSongs.insert(identityKey)
        }
    }
    
    func selectAll(_ songs: [Song]) {
        selectedSongs = Set(songs.map { $0.identityKey })
    }
    
    func clearSelection() {
        selectedSongs.removeAll()
        selectionMode = false
    }
    
    func isSelected(_ identityKey: String) -> Bool {
        selectedSongs.contains(identityKey)
    }
    
    /// 批量添加到歌单
    func addSelectedToPlaylist(songs: [Song], playlistID: UUID) {
        let selected = songs.filter { selectedSongs.contains($0.identityKey) }
        for song in selected {
            _ = UserPlaylistStore.shared.add(song: song, to: playlistID)
        }
        clearSelection()
    }
    
    /// 批量收藏
    func favoriteSelected(songs: [Song]) async {
        let selected = songs.filter { selectedSongs.contains($0.identityKey) }
        for song in selected {
            _ = await FavoritesStore.shared.toggle(song)
        }
        clearSelection()
    }
    
    /// 批量下载
    func downloadSelected(songs: [Song]) {
        let selected = songs.filter { selectedSongs.contains($0.identityKey) }
        Task {
            for song in selected {
                _ = await DownloadManager.shared.download(song: song, quality: .high)
            }
        }
        clearSelection()
    }
    
    /// 批量播放
    func playSelected(songs: [Song]) {
        let selected = songs.filter { selectedSongs.contains($0.identityKey) }
        if !selected.isEmpty {
            PlayerManager.shared?.play(songs: selected, startAt: 0)
        }
        clearSelection()
    }
}
