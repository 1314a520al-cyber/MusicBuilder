import Foundation

// MARK: - 听歌时长统计 + 等级经验系统

final class ListeningStatsStore: ObservableObject {
    static let shared = ListeningStatsStore()

    @Published private(set) var totalSeconds: Int = 0
    @Published private(set) var todaySeconds: Int = 0
    @Published private(set) var weekSeconds: Int = 0
    @Published private(set) var totalSongs: Int = 0
    @Published private(set) var todaySongs: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var exp: Int = 0
    @Published private(set) var lastDate: String = ""

    private let saveKey = "beans.listening.stats"
    private var timer: Timer?
    private var lastTick: Date?

    /// 升级所需经验（每级递增）
    static func expForLevel(_ lv: Int) -> Int {
        100 + (lv - 1) * 80  // Lv1=100, Lv2=180, Lv3=260...
    }

    var expProgress: Double {
        let need = Self.expForLevel(level)
        return min(Double(exp) / Double(need), 1.0)
    }

    var expToNext: Int {
        max(0, Self.expForLevel(level) - exp)
    }

    var totalTimeText: String {
        formatDuration(totalSeconds)
    }

    var todayTimeText: String {
        formatDuration(todaySeconds)
    }

    var weekTimeText: String {
        formatDuration(weekSeconds)
    }

    var levelTitle: String {
        switch level {
        case 1...5: return "初听者"
        case 6...10: return "音乐爱好者"
        case 11...20: return "资深乐迷"
        case 21...35: return "音乐达人"
        case 36...50: return "音乐大师"
        case 51...80: return "传奇听众"
        default: return "音乐之神"
        }
    }

    private var isPlaying = false

    init() {
        load()
        checkDayReset()
        // 监听播放状态变化（不依赖 PlayerManager.shared 时序）
        NotificationCenter.default.addObserver(forName: .beansPlaybackStateDidChange, object: nil, queue: .main) { [weak self] note in
            if let playing = note.userInfo?["isPlaying"] as? Bool {
                self?.isPlaying = playing
            }
        }
        // Timer 延迟到 5 秒后启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.startTimer()
        }
    }

    // MARK: - 计时

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        lastTick = Date()
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        // 只在播放中计时（用本地状态，避免单例时序问题）
        guard isPlaying || PlayerManager.shared?.isPlaying == true else {
            lastTick = Date()
            return
        }
        checkDayReset()
        totalSeconds += 1
        todaySeconds += 1
        weekSeconds += 1
        // 每 30 秒给 1 经验
        if totalSeconds % 30 == 0 {
            addExp(1)
        }
        if totalSeconds % 60 == 0 {
            save()
        }
    }

    func recordSongPlayed() {
        totalSongs += 1
        todaySongs += 1
        save()
    }

    private func addExp(_ amount: Int) {
        exp += amount
        while exp >= Self.expForLevel(level) {
            exp -= Self.expForLevel(level)
            level += 1
        }
    }

    // MARK: - 跨天重置

    private func checkDayReset() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        if lastDate != today {
            if !lastDate.isEmpty {
                todaySeconds = 0
                todaySongs = 0
            }
            lastDate = today
            // 每周重置（简单按自然周）
            let cal = Calendar.current
            if cal.component(.weekday, from: Date()) == 2 { // 周一
                weekSeconds = 0
            }
            save()
        }
    }

    // MARK: - 持久化

    private struct StatsData: Codable {
        var totalSeconds: Int
        var todaySeconds: Int
        var weekSeconds: Int
        var totalSongs: Int
        var todaySongs: Int
        var level: Int
        var exp: Int
        var lastDate: String
    }

    private func save() {
        let data = StatsData(
            totalSeconds: totalSeconds, todaySeconds: todaySeconds,
            weekSeconds: weekSeconds, totalSongs: totalSongs,
            todaySongs: todaySongs, level: level, exp: exp, lastDate: lastDate
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode(StatsData.self, from: data) else { return }
        totalSeconds = decoded.totalSeconds
        todaySeconds = decoded.todaySeconds
        weekSeconds = decoded.weekSeconds
        totalSongs = decoded.totalSongs
        todaySongs = decoded.todaySongs
        level = decoded.level
        exp = decoded.exp
        lastDate = decoded.lastDate
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)秒" }
        if seconds < 3600 { return "\(seconds / 60)分钟" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)小时\(m)分"
    }
}
