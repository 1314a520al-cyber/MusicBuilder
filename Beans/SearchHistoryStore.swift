import Foundation

// MARK: - 搜索历史管理

final class SearchHistoryStore: ObservableObject {
    static let shared = SearchHistoryStore()
    
    @Published private(set) var history: [String] = []
    private let defaults = UserDefaults.standard
    private let key = "beans.searchHistory"
    private let maxCount = 20
    
    let hotSearches = ["周杰伦", "晴天", "林俊杰", "陈奕迅", "邓紫棋", "薛之谦", "毛不易", "许嵩", "汪苏泷", "五月天"]
    
    private init() {
        load()
    }
    
    func add(_ keyword: String) {
        record(keyword)
    }
    
    func record(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        history.removeAll { $0 == trimmed }
        history.insert(trimmed, at: 0)
        if history.count > maxCount {
            history = Array(history.prefix(maxCount))
        }
        save()
    }
    
    func remove(_ keyword: String) {
        history.removeAll { $0 == keyword }
        save()
    }
    
    func clear() {
        history.removeAll()
        save()
    }
    
    private func load() {
        history = defaults.stringArray(forKey: key) ?? []
    }
    
    private func save() {
        defaults.set(history, forKey: key)
    }
}

// MARK: - 播放进度记忆

final class PlaybackProgressStore {
    static let shared = PlaybackProgressStore()
    
    private let defaults = UserDefaults.standard
    private let key = "beans.playbackProgress"
    
    private init() {}
    
    func saveProgress(songID: String, position: TimeInterval) {
        guard position > 5 else { return } // 小于5秒不保存
        var progress = defaults.dictionary(forKey: key) ?? [:]
        progress[songID] = position
        defaults.set(progress, forKey: key)
    }
    
    func getProgress(songID: String) -> TimeInterval? {
        guard let progress = defaults.dictionary(forKey: key),
              let position = progress[songID] as? TimeInterval else { return nil }
        return position > 5 ? position : nil
    }
    
    func clearProgress(songID: String) {
        var progress = defaults.dictionary(forKey: key) ?? [:]
        progress.removeValue(forKey: songID)
        defaults.set(progress, forKey: key)
    }
}
