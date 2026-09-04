import Foundation
/// 收藏管理（红心）：本地优先，任何音源（含同步/直链歌曲）都能立即收藏；
/// 网易云 / QQ 登录后再尽力同步到对应云端，失败不影响本地收藏。
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    /// 通用本地收藏（覆盖所有音源，含第三方解析与同步歌单）
    @Published private(set) var localSongs: [Song] = []
    /// QQ 红心收藏（本地持久化，供音乐库展示）
    @Published private(set) var qqFavoriteSongs: [Song] = []
    /// 网易云红心收藏（本地缓存 + 云端同步）
    @Published private(set) var neteaseFavoriteSongs: [Song] = []
    /// 酷狗红心收藏（本地持久化，供音乐库展示）
    @Published private(set) var kugouFavoriteSongs: [Song] = []
    private let defaults = UserDefaults.standard
    private let localKey = "beans.fav.local.v1"
    private let neteaseKey = "beans.fav.netease.v1"
    private let qqKey = "beans.fav.qq.v1"
    private let kugouKey = "beans.fav.kugou.v1"
    private init() {
        localSongs = Self.loadSongs(localKey)
        qqFavoriteSongs = Self.loadSongs(qqKey)
        neteaseFavoriteSongs = Self.loadSongs(neteaseKey)
        kugouFavoriteSongs = Self.loadSongs(kugouKey)
    }
    /// 该歌曲是否已收藏（本地优先，保证任何来源都可判断）
    func isLiked(_ song: Song?) -> Bool {
        guard let song else { return false }
        if localSongs.contains(where: { $0.identityKey == song.identityKey }) { return true }
        switch song.source {
        case .netease:
            return neteaseFavoriteSongs.contains { $0.id == song.id }
        case .qq:
            guard let mid = song.qqMid else { return false }
            return qqFavoriteSongs.contains { $0.qqMid == mid }
        case .kugou:
            let key = song.kugouHash ?? song.kugouAlbumAudioId ?? "\(song.id)"
            return kugouFavoriteSongs.contains {
                ($0.kugouHash ?? $0.kugouAlbumAudioId ?? "\($0.id)") == key
            }
        }
    }
    /// 切换收藏状态：本地立即生效；网易云/QQ/酷狗同时尽力同步云端（失败不回滚本地）
    @discardableResult
    func toggle(_ song: Song) async -> Bool {
        let liked = !isLiked(song)
        updateLocal(song, liked: liked)
        switch song.source {
        case .netease:
            updateNetease(song, liked: liked)
            _ = try? await NetEaseAPI.shared.like(id: song.id, liked: liked)
        case .qq:
            guard let mid = song.qqMid else { break }
            updateQQ(song, liked: liked)
            if QQMusicAuth.shared.isLoggedIn {
                _ = try? await QQMusicAPI.shared.like(songmid: mid, liked: liked)
            }
        case .kugou:
            updateKugou(song, liked: liked)
            // 酷狗收藏接口较复杂，本地收藏优先，云端同步尽力而为
            if KugouMusicAuth.shared.isLoggedIn {
                _ = try? await KugouMusicAPI.shared.like(song: song, liked: liked)
            }
        }
        return true
    }
    /// 移除 QQ 收藏（音乐库侧滑删除）
    func removeQQFavorite(_ song: Song) {
        updateQQ(song, liked: false)
    }
    /// 移除酷狗收藏（音乐库侧滑删除）
    func removeKugouFavorite(_ song: Song) {
        updateKugou(song, liked: false)
    }
    private func updateKugou(_ song: Song, liked: Bool) {
        let key = song.kugouHash ?? song.kugouAlbumAudioId ?? "\(song.id)"
        if liked {
            kugouFavoriteSongs.removeAll {
                ($0.kugouHash ?? $0.kugouAlbumAudioId ?? "\($0.id)") == key
            }
            kugouFavoriteSongs.insert(song, at: 0)
        } else {
            kugouFavoriteSongs.removeAll {
                ($0.kugouHash ?? $0.kugouAlbumAudioId ?? "\($0.id)") == key
            }
        }
        saveSongs(kugouFavoriteSongs, key: kugouKey)
    }
    private func updateLocal(_ song: Song, liked: Bool) {
        if liked {
            guard !localSongs.contains(where: { $0.id == song.id }) else { return }
            localSongs.insert(song, at: 0)
        } else {
            localSongs.removeAll { $0.id == song.id }
        }
        saveSongs(localSongs, key: localKey)
    }
    private func updateNetease(_ song: Song, liked: Bool) {
        if liked {
            neteaseFavoriteSongs.removeAll { $0.id == song.id }
            neteaseFavoriteSongs.insert(song, at: 0)
        } else {
            neteaseFavoriteSongs.removeAll { $0.id == song.id }
        }
        saveSongs(neteaseFavoriteSongs, key: neteaseKey)
    }
    private func updateQQ(_ song: Song, liked: Bool) {
        if liked {
            qqFavoriteSongs.removeAll { $0.qqMid != nil && $0.qqMid == song.qqMid }
            qqFavoriteSongs.insert(song, at: 0)
        } else {
            qqFavoriteSongs.removeAll { $0.qqMid != nil && $0.qqMid == song.qqMid }
        }
        saveSongs(qqFavoriteSongs, key: qqKey)
    }
    private static func loadSongs(_ key: String) -> [Song] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([Song].self, from: data) else { return [] }
        return saved
    }
    private func saveSongs(_ songs: [Song], key: String) {
        if let data = try? JSONEncoder().encode(songs) {
            defaults.set(data, forKey: key)
        }
    }
    /// 退出网易云登录时清空本地网易云收藏缓存（保留通用本地收藏与 QQ 收藏）
    func resetNetease() {
        neteaseFavoriteSongs = []
        defaults.removeObject(forKey: neteaseKey)
    }
}
