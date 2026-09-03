import Foundation
import UIKit

// MARK: - 同步管理器（兼容洛雪音乐同步协议）

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    private let defaults = UserDefaults.standard
    private let urlKey = "sync.serverURL"
    private let pwdKey = "sync.password"
    private let enabledKey = "sync.enabled"
    private let lastSyncKey = "sync.lastSyncTime"
    private let deviceKey = "sync.deviceName"
    
    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var syncLog: [String] = []
    
    var serverURL: String {
        get { defaults.string(forKey: urlKey) ?? "" }
        set { defaults.set(newValue, forKey: urlKey) }
    }
    
    var password: String {
        get { defaults.string(forKey: pwdKey) ?? "" }
        set { defaults.set(newValue, forKey: pwdKey) }
    }
    
    var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }
    
    var lastSyncTime: Date {
        get { Date(timeIntervalSince1970: defaults.double(forKey: lastSyncKey)) }
        set { defaults.set(newValue.timeIntervalSince1970, forKey: lastSyncKey) }
    }
    
    var hasSynced: Bool { defaults.double(forKey: lastSyncKey) > 0 }
    
    var deviceName: String {
        get {
            let name = defaults.string(forKey: deviceKey) ?? ""
            return name.isEmpty ? "iOS-\(UIDevice.current.name)" : name
        }
        set { defaults.set(newValue, forKey: deviceKey) }
    }
    
    private init() {}
    
    // MARK: - 同步数据结构
    
    struct SyncData: Codable {
        let version: String
        let deviceName: String
        let timestamp: Double
        let playlists: [SyncPlaylist]
        let favorites: [SyncSong]
    }
    
    struct SyncPlaylist: Codable {
        let id: String
        let name: String
        let songs: [SyncSong]
    }
    
    struct SyncSong: Codable {
        let id: String
        let name: String
        let artist: String
        let source: String
        let duration: Double
    }
    
    // MARK: - 上传歌单
    
    func uploadPlaylists() async -> Bool {
        guard !serverURL.isEmpty, !password.isEmpty else {
            lastError = "请先配置同步地址和密码"
            return false
        }
        
        isSyncing = true
        lastError = nil
        log("开始上传歌单...")
        
        do {
            let data = try await buildSyncData()
            let jsonData = try JSONEncoder().encode(data)
            
            var request = URLRequest(url: URL(string: serverURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(password, forHTTPHeaderField: "X-Sync-Password")
            request.setValue(deviceName, forHTTPHeaderField: "X-Device-Name")
            request.httpBody = jsonData
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    lastSyncTime = Date()
                    log("上传成功！同步了 \(data.playlists.count) 个歌单，\(data.favorites.count) 首收藏")
                    isSyncing = false
                    return true
                } else {
                    let errorMsg = String(data: responseData, encoding: .utf8) ?? "未知错误"
                    lastError = "上传失败（HTTP \(http.statusCode)）"
                    log("上传失败：HTTP \(http.statusCode) - \(errorMsg.prefix(80))")
                }
            }
        } catch {
            lastError = "上传失败：\(error.localizedDescription)"
            log("上传失败：\(error.localizedDescription)")
        }
        
        isSyncing = false
        return false
    }
    
    // MARK: - 下载歌单
    
    func downloadPlaylists() async -> Bool {
        guard !serverURL.isEmpty, !password.isEmpty else {
            lastError = "请先配置同步地址和密码"
            return false
        }
        
        isSyncing = true
        lastError = nil
        log("开始下载歌单...")
        
        do {
            var request = URLRequest(url: URL(string: serverURL)!)
            request.httpMethod = "GET"
            request.setValue(password, forHTTPHeaderField: "X-Sync-Password")
            request.setValue(deviceName, forHTTPHeaderField: "X-Device-Name")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                let syncData = try JSONDecoder().decode(SyncData.self, from: data)
                try await applySyncData(syncData)
                lastSyncTime = Date()
                log("下载成功！同步了 \(syncData.playlists.count) 个歌单，\(syncData.favorites.count) 首收藏")
                isSyncing = false
                return true
            } else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                lastError = "下载失败（HTTP \(status)）"
                log("下载失败：HTTP \(status)")
            }
        } catch {
            lastError = "下载失败：\(error.localizedDescription)"
            log("下载失败：\(error.localizedDescription)")
        }
        
        isSyncing = false
        return false
    }
    
    // MARK: - 自动同步
    
    func autoSync() async {
        guard isEnabled, !serverURL.isEmpty, !password.isEmpty else { return }
        log("自动同步中...")
        _ = await uploadPlaylists()
    }
    
    // MARK: - Private
    
    private func buildSyncData() async throws -> SyncData {
        let userPlaylists = UserPlaylistStore.shared.playlists
        var syncPlaylists: [SyncPlaylist] = []
        
        for playlist in userPlaylists {
            let songs = playlist.songs.map { song in
                SyncSong(
                    id: song.identityKey,
                    name: song.name,
                    artist: song.artists,
                    source: song.source.rawValue,
                    duration: song.duration
                )
            }
            syncPlaylists.append(SyncPlaylist(
                id: playlist.id.uuidString,
                name: playlist.name,
                songs: songs
            ))
        }
        
        let favorites = FavoritesStore.shared.localSongs.map { song in
            SyncSong(
                id: song.identityKey,
                name: song.name,
                artist: song.artists,
                source: song.source.rawValue,
                duration: song.duration
            )
        }
        
        return SyncData(
            version: "1.0",
            deviceName: deviceName,
            timestamp: Date().timeIntervalSince1970,
            playlists: syncPlaylists,
            favorites: favorites
        )
    }
    
    private func applySyncData(_ data: SyncData) async throws {
        for playlist in data.playlists {
            if UserPlaylistStore.shared.playlists.contains(where: { $0.name == playlist.name }) {
                log("跳过已存在的歌单：\(playlist.name)")
                continue
            }
            let newPlaylist = UserPlaylistStore.shared.create(named: playlist.name)
            for syncSong in playlist.songs {
                let song = Song(
                    id: 0,
                    name: syncSong.name,
                    artists: syncSong.artist,
                    album: "",
                    coverURL: nil,
                    duration: syncSong.duration,
                    source: SongSource(rawValue: syncSong.source) ?? .netease,
                    fee: 0
                )
                _ = UserPlaylistStore.shared.add(song: song, to: newPlaylist.id)
            }
            log("导入歌单：\(playlist.name)（\(playlist.songs.count)首）")
        }
        
        var imported = 0
        for syncSong in data.favorites {
            let song = Song(
                id: 0,
                name: syncSong.name,
                artists: syncSong.artist,
                album: "",
                coverURL: nil,
                duration: syncSong.duration,
                source: SongSource(rawValue: syncSong.source) ?? .netease,
                fee: 0
            )
            if !FavoritesStore.shared.isLiked(song) {
                _ = await FavoritesStore.shared.toggle(song)
                imported += 1
            }
        }
        if imported > 0 { log("导入收藏：\(imported)首") }
    }
    
    private func log(_ message: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        syncLog.insert("[\(time)] \(message)", at: 0)
        if syncLog.count > 50 { syncLog.removeLast() }
    }
    
    func clearLog() {
        syncLog.removeAll()
    }
}
