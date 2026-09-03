import Foundation

/// 用户自建歌单：不依赖任何平台登录，任何音源的歌曲都能加入。
struct UserPlaylist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var songs: [Song] = []
    var updatedAt: Date = Date()
}

final class UserPlaylistStore: ObservableObject {
    static let shared = UserPlaylistStore()
    @Published private(set) var playlists: [UserPlaylist] = []
    private let defaults = UserDefaults.standard
    private let key = "music.userPlaylists.v1"

    private init() { load() }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode([UserPlaylist].self, from: data) else { return }
        playlists = saved
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(playlists) { defaults.set(data, forKey: key) }
    }

    @discardableResult
    func create(named name: String) -> UserPlaylist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = UserPlaylist(name: trimmed.isEmpty ? "新建歌单" : trimmed)
        playlists.insert(p, at: 0); persist(); return p
    }

    /// 加入歌曲，返回是否为新增
    @discardableResult
    func add(song: Song, to id: UUID) -> Bool {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return false }
        if playlists[idx].songs.contains(where: { $0.id == song.id }) { return false }
        playlists[idx].songs.insert(song, at: 0)
        playlists[idx].updatedAt = Date()
        persist(); return true
    }

    func remove(songID: Int, from id: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[idx].songs.removeAll { $0.id == songID }; persist()
    }
    func delete(_ id: UUID) {
        playlists.removeAll { $0.id == id }; persist()
    }
}
