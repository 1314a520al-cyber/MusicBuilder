import Foundation

/// 从付费音乐源同步下来的歌单（每个音源一份，按音源 id 覆盖更新）。
struct SyncedPlaylist: Identifiable, Codable, Hashable {
    /// 对应 ThirdPartySource.id
    let id: String
    var name: String
    var sourceName: String
    var songs: [Song]
    var updatedAt: Date
}

/// 音源歌单同步结果
enum SyncOutcome {
    case success(count: Int)
    case empty
    case failure(String)
}

/// 管理所有“购买后可同步歌单”的音源歌单，持久化到本地并在音乐库展示。
final class SyncedPlaylistStore: ObservableObject {
    static let shared = SyncedPlaylistStore()
    @Published private(set) var playlists: [SyncedPlaylist] = []
    private let defaults = UserDefaults.standard
    private let key = "beans.syncedPlaylists.v1"
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 25
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    private init() {
        if let data = defaults.data(forKey: key),
           let list = try? JSONDecoder().decode([SyncedPlaylist].self, from: data) {
            playlists = list
        }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(playlists) {
            defaults.set(data, forKey: key)
        }
    }
    var totalSongs: Int { playlists.reduce(0) { $0 + $1.songs.count } }
    func playlist(for sourceID: String) -> SyncedPlaylist? {
        playlists.first { $0.id == sourceID }
    }
    func remove(for sourceID: String) {
        playlists.removeAll { $0.id == sourceID }
        persist()
    }
    func clearAll() {
        playlists.removeAll()
        persist()
    }

    /// 拉取并同步某个音源的歌单
    @discardableResult
    func sync(_ source: ThirdPartySource) async -> SyncOutcome {
        guard source.canSyncPlaylist else {
            return .failure("该音源未配置同步地址或卡密缺失")
        }
        var urlString = source.playlistTemplate
        urlString = urlString.replacingOccurrences(of: "{key}", with: urlEncoded(source.cardKey))
        urlString = urlString.replacingOccurrences(of: "{quality}", with: source.headers["quality"] ?? "320k")
        guard let url = URL(string: urlString) else {
            return .failure("同步地址格式不正确")
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Music-Source/1.0", forHTTPHeaderField: "User-Agent")
        if let apiKey = source.headers["apiKey"], !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        } else if !source.cardKey.isEmpty {
            request.setValue(source.cardKey, forHTTPHeaderField: "X-API-Key")
            request.setValue(source.cardKey, forHTTPHeaderField: "Authorization")
        }
        let data: Data
        do {
            data = try await session.data(for: request).0
        } catch {
            return .failure("网络请求失败：\(error.localizedDescription)")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure("返回内容不是有效 JSON")
        }
        if let code = intValue(obj["code"]), code != 200, code != 0, code != 1 {
            let msg = obj["message"] as? String ?? obj["msg"] as? String ?? "code=\(code)"
            return .failure("音源返回错误：\(msg)")
        }
        guard let array = arrayAtAnyPath(obj, source.playlistPath) as? [[String: Any]] else {
            return .failure("未在指定路径找到歌曲列表")
        }
        let songs = array.enumerated().compactMap { index, dict in
            Self.makeSong(dict: dict, source: source, index: index)
        }
        guard !songs.isEmpty else { return .empty }
        await MainActor.run {
            let playlist = SyncedPlaylist(
                id: source.id,
                name: "\(source.name) · 歌单",
                sourceName: source.name,
                songs: songs,
                updatedAt: Date()
            )
            if let idx = playlists.firstIndex(where: { $0.id == source.id }) {
                playlists[idx] = playlist
            } else {
                playlists.append(playlist)
            }
            persist()
        }
        return .success(count: songs.count)
    }

    // MARK: - 解析
    private static func makeSong(dict: [String: Any], source: ThirdPartySource, index: Int) -> Song? {
        guard let name = firstString(dict, ["name", "songName", "title", "musicName"]), !name.isEmpty else {
            return nil
        }
        let artists = artistString(dict)
        let album = firstString(dict, ["album", "albumName", "album_name"]) ?? ""
        let cover = firstString(dict, ["cover", "coverUrl", "pic", "picUrl", "albumPic", "image", "img"])
            .flatMap { URL(string: $0) }
        var duration: TimeInterval = 0
        if let d = firstDouble(dict, ["duration", "dt", "length", "time"]) {
            duration = d > 1000 ? d / 1000.0 : d
        }
        let urlString = firstString(dict, source.songURLField.split(separator: "|").map(String.init))
        let directURL = urlString.flatMap { URL(string: $0) }
        // 直链是同步歌单可播放的关键；没有直链则跳过（无法离线映射到平台 ID）
        guard let directURL else { return nil }
        let stableID = stableIntID("\(source.id)-\(name)-\(artists)-\(index)")
        return Song(
            id: stableID,
            name: name,
            artists: artists,
            album: album,
            coverURL: cover,
            duration: duration,
            source: .netease,
            fee: 0,
            directURL: directURL,
            directSourceName: source.name
        )
    }
    private static func artistString(_ dict: [String: Any]) -> String {
        if let s = firstString(dict, ["artist", "artists", "singer", "author", "artistName"]) {
            return s
        }
        for key in ["artists", "artist", "singers"] {
            if let arr = dict[key] as? [[String: Any]] {
                return arr.compactMap { $0["name"] as? String }.joined(separator: " / ")
            }
            if let arr = dict[key] as? [String] {
                return arr.joined(separator: " / ")
            }
        }
        return ""
    }
    private static func firstString(_ dict: [String: Any], _ keys: [String]) -> String? {
        for k in keys {
            if let s = dict[k] as? String, !s.isEmpty { return s }
            if let n = dict[k] as? NSNumber { return n.stringValue }
        }
        return nil
    }
    private static func firstDouble(_ dict: [String: Any], _ keys: [String]) -> Double? {
        for k in keys {
            if let n = dict[k] as? NSNumber { return n.doubleValue }
            if let s = dict[k] as? String, let d = Double(s) { return d }
        }
        return nil
    }
    private func arrayAtAnyPath(_ obj: [String: Any], _ paths: String) -> Any? {
        for path in paths.split(separator: "|") {
            if let value = valueAtPath(obj, String(path)) { return value }
        }
        return nil
    }
    private func valueAtPath(_ obj: Any, _ path: String) -> Any? {
        var current: Any = obj
        for key in path.split(separator: ".") {
            if let dict = current as? [String: Any] {
                current = dict[String(key)]
            } else if let arr = current as? [Any] {
                guard let idx = Int(String(key)), idx < arr.count else { return nil }
                current = arr[idx]
            } else {
                return nil
            }
        }
        return current
    }
    private func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String { return Int(s) }
        return nil
    }
    private func urlEncoded(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
    /// 稳定字符串哈希 → 正 Int（保证跨启动一致、同一音源内不撞车）
    private static func stableIntID(_ seed: String) -> Int {
        var hash: UInt64 = 5381
        for byte in seed.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Int(hash % 2_000_000_000) + 1
    }
}
