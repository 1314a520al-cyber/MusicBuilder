import Foundation

/// 小组件数据同步：把当前播放歌曲和推荐写入 App Group，供桌面小组件读取
final class WidgetSyncManager {
    static let shared = WidgetSyncManager()
    private let groupID = "group.com.article.app"
    private let nowPlayingKey = "music.nowPlaying"
    private let recommendationsKey = "music.recommendations"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    private init() {}

    /// 更新当前播放歌曲到小组件
    func updateNowPlaying(songName: String, artist: String, coverURL: String, isPlaying: Bool) {
        guard let defaults = self.defaults else { return }
        do {
            let data: [String: Any] = [
                "songName": songName,
                "artist": artist,
                "coverURL": coverURL,
                "isPlaying": isPlaying,
                "timestamp": Date().timeIntervalSince1970
            ]
            let json = try JSONSerialization.data(withJSONObject: data)
            defaults.set(json, forKey: nowPlayingKey)
        } catch {
            // 静默失败，不影响主应用
        }
    }

    /// 更新推荐列表到小组件
    func updateRecommendations(_ list: [String]) {
        defaults?.set(list, forKey: recommendationsKey)
    }

    /// 清空当前播放
    func clearNowPlaying() {
        defaults?.removeObject(forKey: nowPlayingKey)
    }
}
