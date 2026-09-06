import Foundation

// MARK: - 重复歌曲检测

struct DuplicateSong: Identifiable {
    let id = UUID()
    let name: String
    let artists: String
    let count: Int
    let songs: [Song]
}

final class DuplicateDetector {
    static func detect(in songs: [Song]) -> [DuplicateSong] {
        var groups: [String: [Song]] = [:]
        for song in songs {
            let key = "\(song.name.lowercased())|\(song.artists.lowercased())"
            groups[key, default: []].append(song)
        }
        return groups
            .filter { $0.value.count > 1 }
            .map { DuplicateSong(name: $0.value[0].name, artists: $0.value[0].artists, count: $0.value.count, songs: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - 每周听歌报告

struct WeeklyReport {
    let totalMinutes: Int
    let totalSongs: Int
    let topArtists: [(name: String, count: Int)]
    let topSongs: [(name: String, count: Int)]
    let favoriteGenre: String
    let mostActiveHour: Int
    let skippedCount: Int
    
    var summary: String {
        """
        本周你共听歌 \(totalMinutes) 分钟，播放了 \(totalSongs) 首歌曲。
        最爱的歌手是 \(topArtists.first?.name ?? "未知")，听了 \(topArtists.first?.count ?? 0) 次。
        最活跃的时段是 \(mostActiveHour):00，跳过了 \(skippedCount) 首歌。
        """
    }
}

final class ListeningStatsTracker {
    static let shared = ListeningStatsTracker()
    
    private let defaults = UserDefaults.standard
    private let statsKey = "beans.listeningStats"
    
    struct DailyStats: Codable {
        var date: String
        var playCount: Int
        var skipCount: Int
        var totalSeconds: Int
        var artistCounts: [String: Int]
        var songCounts: [String: Int]
        var hourCounts: [Int: Int]
    }
    
    private init() {}
    
    func recordPlay(song: Song, duration: TimeInterval) {
        var stats = todayStats()
        stats.playCount += 1
        stats.totalSeconds += Int(duration)
        stats.artistCounts[song.artists, default: 0] += 1
        stats.songCounts[song.name, default: 0] += 1
        let hour = Calendar.current.component(.hour, from: Date())
        stats.hourCounts[hour, default: 0] += 1
        saveStats(stats)
    }
    
    func recordSkip() {
        var stats = todayStats()
        stats.skipCount += 1
        saveStats(stats)
    }
    
    func weeklyReport() -> WeeklyReport {
        var totalSeconds = 0
        var totalSongs = 0
        var totalSkips = 0
        var artistAgg: [String: Int] = [:]
        var songAgg: [String: Int] = [:]
        var hourAgg: [Int: Int] = [:]
        
        for day in 0..<7 {
            if let date = Calendar.current.date(byAdding: .day, value: -day, to: Date()) {
                let key = dateKey(date)
                if let data = defaults.data(forKey: "\(statsKey)_\(key)"),
                   let stats = try? JSONDecoder().decode(DailyStats.self, from: data) {
                    totalSeconds += stats.totalSeconds
                    totalSongs += stats.playCount
                    totalSkips += stats.skipCount
                    for (k, v) in stats.artistCounts { artistAgg[k, default: 0] += v }
                    for (k, v) in stats.songCounts { songAgg[k, default: 0] += v }
                    for (k, v) in stats.hourCounts { hourAgg[k, default: 0] += v }
                }
            }
        }
        
        let topArtists = artistAgg.sorted { $0.value > $1.value }.prefix(5).map { (name: $0.key, count: $0.value) }
        let topSongs = songAgg.sorted { $0.value > $1.value }.prefix(5).map { (name: $0.key, count: $0.value) }
        let mostActiveHour = hourAgg.sorted { $0.value > $1.value }.first?.key ?? 20
        
        return WeeklyReport(
            totalMinutes: totalSeconds / 60,
            totalSongs: totalSongs,
            topArtists: Array(topArtists),
            topSongs: Array(topSongs),
            favoriteGenre: "流行",
            mostActiveHour: mostActiveHour,
            skippedCount: totalSkips
        )
    }
    
    private func todayStats() -> DailyStats {
        let key = dateKey(Date())
        if let data = defaults.data(forKey: "\(statsKey)_\(key)"),
           let stats = try? JSONDecoder().decode(DailyStats.self, from: data) {
            return stats
        }
        return DailyStats(date: key, playCount: 0, skipCount: 0, totalSeconds: 0, artistCounts: [:], songCounts: [:], hourCounts: [:])
    }
    
    private func saveStats(_ stats: DailyStats) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: "\(statsKey)_\(stats.date)")
        }
    }
    
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
