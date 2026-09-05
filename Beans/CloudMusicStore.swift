import Foundation

// MARK: - 云端音乐管理器（网盘 + QQ + 网易云 + 酷狗）

@MainActor
final class CloudMusicStore: ObservableObject {
    static let shared = CloudMusicStore()
    
    @Published var netdiskSongs: [NetdiskSong] = []
    @Published var qqPlaylists: [Playlist] = []
    @Published var neteasePlaylists: [Playlist] = []
    @Published var kugouPlaylists: [Playlist] = []
    @Published var isLoading = false
    @Published var loadingSection: CloudSection? = nil
    
    enum CloudSection: String {
        case netdisk = "网盘音乐"
        case qq = "QQ音乐"
        case netease = "网易云音乐"
        case kugou = "酷狗音乐"
    }
    
    struct NetdiskSong: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let artist: String
        let size: Int64
        let downloadURL: String?
        let driveName: String
        let path: String
    }
    
    private init() {}
    
    // MARK: - 加载网盘歌曲
    
    func loadNetdiskSongs() async {
        loadingSection = .netdisk
        isLoading = true
        netdiskSongs = []
        
        let accounts = CloudDriveStore.shared.accounts.filter { $0.isLoggedIn }
        guard !accounts.isEmpty else {
            isLoading = false
            loadingSection = nil
            return
        }
        
        for account in accounts {
            let songs = await fetchNetdiskMusicFiles(account: account)
            netdiskSongs.append(contentsOf: songs)
        }
        
        isLoading = false
        loadingSection = nil
    }
    
    private func fetchNetdiskMusicFiles(account: CloudDriveAccount) async -> [NetdiskSong] {
        guard let cookies = account.cookies, !cookies.isEmpty else { return [] }
        
        var songs: [NetdiskSong] = []
        let musicExts = ["mp3", "flac", "wav", "m4a", "ape", "ogg", "aac", "wma", "dsf", "dff"]
        
        // 根据网盘类型调用不同API
        switch account.name {
        case "迅雷云盘":
            songs = await fetchXunleiFiles(cookies: cookies, driveName: account.name)
        case "夸克网盘":
            songs = await fetchQuarkFiles(cookies: cookies, driveName: account.name)
        case "UC 网盘":
            songs = await fetchUCFiles(cookies: cookies, driveName: account.name)
        default:
            break
        }
        
        return songs.filter { song in
            let ext = (song.name as NSString).pathExtension.lowercased()
            return musicExts.contains(ext)
        }
    }
    
    // 迅雷云盘文件列表
    private func fetchXunleiFiles(cookies: String, driveName: String) async -> [NetdiskSong] {
        var songs: [NetdiskSong] = []
        guard let url = URL(string: "https://api-pan.xunlei.com/drive/v1/files?parent_id=root&limit=200&filters=%7B%22phase%22%3A%7B%22eq%22%3A%22PHASE_TYPE_COMPLETE%22%7D%7D") else { return songs }
        
        var request = URLRequest(url: url)
        request.setValue("cookies=\(cookies)", forHTTPHeaderField: "Cookie")
        request.setValue("https://pan.xunlei.com", forHTTPHeaderField: "Referer")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let files = json["files"] as? [[String: Any]] {
                for file in files {
                    if let name = file["name"] as? String,
                       let size = file["size"] as? Int64,
                       let fileId = file["id"] as? String {
                        let downloadURL = "https://api-pan.xunlei.com/drive/v1/files/\(fileId)/download_url"
                        songs.append(NetdiskSong(
                            name: name,
                            artist: (name as NSString).deletingPathExtension,
                            size: size,
                            downloadURL: downloadURL,
                            driveName: driveName,
                            path: "根目录"
                        ))
                    }
                }
            }
        } catch {
            print("迅雷文件获取失败: \(error)")
        }
        return songs
    }
    
    // 夸克网盘文件列表
    private func fetchQuarkFiles(cookies: String, driveName: String) async -> [NetdiskSong] {
        var songs: [NetdiskSong] = []
        guard let url = URL(string: "https://drive-pc.quark.cn/1/clouddrive/file/sort?pr=ucpro&fr=pc&pdir_fid=0&_page=1&_size=200&_sort=file_type:asc,file_name:asc") else { return songs }
        
        var request = URLRequest(url: url)
        request.setValue(cookies, forHTTPHeaderField: "Cookie")
        request.setValue("https://pan.quark.cn", forHTTPHeaderField: "Referer")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let data = json["data"] as? [String: Any],
               let list = data["list"] as? [[String: Any]] {
                for file in list {
                    if let name = file["file_name"] as? String,
                       let size = file["size"] as? Int64,
                       let fid = file["fid"] as? String {
                        songs.append(NetdiskSong(
                            name: name,
                            artist: (name as NSString).deletingPathExtension,
                            size: size,
                            downloadURL: "https://drive-pc.quark.cn/1/clouddrive/file/download?pr=ucpro&fr=pc&fid=\(fid)",
                            driveName: driveName,
                            path: "根目录"
                        ))
                    }
                }
            }
        } catch {
            print("夸克文件获取失败: \(error)")
        }
        return songs
    }
    
    // UC网盘文件列表（同夸克）
    private func fetchUCFiles(cookies: String, driveName: String) async -> [NetdiskSong] {
        return await fetchQuarkFiles(cookies: cookies, driveName: driveName)
    }
    
    // MARK: - 加载QQ歌单
    
    func loadQQPlaylists() async {
        loadingSection = .qq
        isLoading = true
        qqPlaylists = []
        
        if !QQMusicAuth.shared.uin.isEmpty {
            qqPlaylists = (try? await QQMusicAPI.shared.userPlaylists(uin: QQMusicAuth.shared.uin)) ?? []
        }
        
        isLoading = false
        loadingSection = nil
    }
    
    // MARK: - 加载网易云歌单
    
    func loadNeteasePlaylists() async {
        loadingSection = .netease
        isLoading = true
        neteasePlaylists = []
        
        if let data = UserDefaults.standard.data(forKey: "beans.user"),
           let user = try? JSONDecoder().decode(NetEaseUser.self, from: data) {
            neteasePlaylists = (try? await NetEaseAPI.shared.userPlaylists(uid: user.uid)) ?? []
        }
        
        isLoading = false
        loadingSection = nil
    }
    
    // MARK: - 加载酷狗歌单
    
    func loadKugouPlaylists() async {
        loadingSection = .kugou
        isLoading = true
        kugouPlaylists = []
        
        if KugouMusicAuth.shared.isLoggedIn {
            kugouPlaylists = (try? await KugouMusicAPI.shared.userPlaylists()) ?? []
        }
        
        isLoading = false
        loadingSection = nil
    }
    
    // MARK: - 获取歌单歌曲
    
    func loadPlaylistSongs(playlist: Playlist, source: CloudSection) async -> [Song] {
        switch source {
        case .qq:
            return (try? await QQMusicAPI.shared.playlistSongs(listID: playlist.id)) ?? []
        case .netease:
            return (try? await NetEaseAPI.shared.playlistTracks(id: playlist.id)) ?? []
        case .kugou:
            return (try? await KugouMusicAPI.shared.playlistSongs(listID: playlist.id)) ?? []
        default:
            return []
        }
    }
    
    // MARK: - 播放网盘歌曲（自动识别封面和歌词）
    
    func playNetdiskSong(_ song: NetdiskSong) {
        guard let urlStr = song.downloadURL, let url = URL(string: urlStr) else { return }
        
        // 先直接播放（用文件名作为标题）
        let music = Song(
            id: 0,
            name: (song.name as NSString).deletingPathExtension,
            artists: song.artist,
            album: song.driveName,
            coverURL: nil,
            duration: 0,
            source: .netease,
            directURL: url,
            directSourceName: song.driveName
        )
        PlayerManager.shared?.play(songs: [music], startAt: 0)
        
        // 后台搜索匹配封面和歌词
        Task {
            let keyword = "\((song.name as NSString).deletingPathExtension) \(song.artist)"
            if let results = try? await NetEaseAPI.shared.search(keyword: keyword, limit: 5),
               let match = results.first(where: { result in
                   result.name.lowercased().contains((song.name as NSString).deletingPathExtension.prefix(4).lowercased())
               }) {
                // 用搜索到的歌曲ID和封面替换当前播放歌曲
                let enriched = Song(
                    id: match.id,
                    name: match.name,
                    artists: match.artists,
                    album: match.album,
                    coverURL: match.coverURL,
                    duration: match.duration,
                    source: .netease,
                    directURL: url,
                    directSourceName: song.driveName
                )
                await MainActor.run {
                    if let idx = PlayerManager.shared?.queue.firstIndex(where: { $0.identityKey == music.identityKey }) {
                        PlayerManager.shared?.queue[idx] = enriched
                    }
                }
            }
        }
    }
}
