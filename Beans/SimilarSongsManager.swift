import Foundation

// MARK: - 相似歌曲推荐 & 智能电台

@MainActor
final class SimilarSongsManager: ObservableObject {
    static let shared = SimilarSongsManager()
    
    @Published var similarSongs: [Song] = []
    @Published var isLoading = false
    @Published var radioSongs: [Song] = []
    @Published var radioMode = false
    
    private init() {}
    
    // MARK: - 获取相似歌曲（基于网易云相似歌曲API + 搜索补充）
    
    func fetchSimilarSongs(for song: Song) async {
        isLoading = true
        similarSongs = []
        
        var results: [Song] = []
        
        // 1. 网易云相似歌曲API
        if song.source == .netease, song.id > 0 {
            if let similar = try? await NetEaseAPI.shared.similarSongs(id: song.id) {
                results.append(contentsOf: similar)
            }
        }
        
        // 2. 如果不够，用关键词搜索补充
        if results.count < 10 {
            let keyword = "\(song.name) \(song.artists)"
            if let searchResults = try? await NetEaseAPI.shared.search(keyword: keyword, limit: 20) {
                for s in searchResults {
                    if !results.contains(where: { $0.identityKey == s.identityKey }) && s.identityKey != song.identityKey {
                        results.append(s)
                    }
                }
            }
        }
        
        // 3. 去重，最多30首
        var seen = Set<String>()
        similarSongs = results.filter { seen.insert($0.identityKey).inserted }.prefix(30).map { $0 }
        
        isLoading = false
    }
    
    // MARK: - 智能电台模式
    
    func startRadio(from song: Song) async {
        radioMode = true
        await fetchSimilarSongs(for: song)
        radioSongs = similarSongs
        if !radioSongs.isEmpty {
            PlayerManager.shared?.play(songs: radioSongs, startAt: 0)
        }
    }
    
    func stopRadio() {
        radioMode = false
        radioSongs = []
    }
    
    // MARK: - 根据情境推荐（时间/场景）
    
    enum Scene: String {
        case morning = "早晨"
        case commute = "通勤"
        case exercise = "运动"
        case sleep = "睡前"
        case night = "深夜"
        case work = "工作"
        
        var keywords: [String] {
            switch self {
            case .morning: return ["早安", "清新", "轻音乐", "民谣"]
            case .commute: return ["流行", "热门", "华语", "欧美"]
            case .exercise: return ["电子", "摇滚", "嘻哈", "运动"]
            case .sleep: return ["催眠", "白噪音", "纯音乐", "钢琴"]
            case .night: return ["爵士", "蓝调", "R&B", "灵魂乐"]
            case .work: return ["纯音乐", "古典", "Lo-Fi", "环境"]
            }
        }
    }
    
    static func currentScene() -> Scene {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<9: return .morning
        case 7..<10: return .commute
        case 17..<19: return .commute
        case 12..<14: return .exercise
        case 21..<24: return .sleep
        case 0..<5: return .night
        case 9..<12, 14..<17: return .work
        default: return .commute
        }
    }
    
    func fetchSceneRecommendations(scene: Scene) async -> [Song] {
        var results: [Song] = []
        for keyword in scene.keywords.prefix(2) {
            if let songs = try? await NetEaseAPI.shared.search(keyword: keyword, limit: 15) {
                results.append(contentsOf: songs)
            }
        }
        var seen = Set<String>()
        return results.filter { seen.insert($0.identityKey).inserted }.prefix(30).map { $0 }
    }
}
