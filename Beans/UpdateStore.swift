import Foundation

/// 版本更新记录
struct UpdateEntry: Codable, Identifiable, Equatable {
    let id: String
    let version: String
    let date: String
    let features: [String]
    let fixes: [String]
    let deletions: [String]
}

final class UpdateStore: ObservableObject {
    static let shared = UpdateStore()
    @Published private(set) var entries: [UpdateEntry] = []
    @Published var showUpdatePrompt = false
    @Published private(set) var latestEntry: UpdateEntry?

    private let key = "music_update_log_v1"
    private let lastSeenKey = "music_last_seen_version"
    
    /// 内置更新日志（所有版本，供init合并和autoCheckVersion查询）
    private static var builtInEntries: [UpdateEntry] {
        return [
                UpdateEntry(id: "v2.10.21", version: "2.10.21", date: "2026-09-06",
                    features: ["显示进度与实际播放时间彻底分离（双变量架构）", "seek只改显示进度，UI/歌词/进度条立刻跳到目标位置", "实际播放时间由时间观察者独立更新，接近目标时才同步显示"],
                    fixes: ["彻底修复点击歌词/±15秒/拖动进度条后进度回退问题（根因：显示进度和实际播放共用同一变量）", "seek后显示进度锁死为目标值，播放器实际在什么位置不影响显示", "只有实际播放到目标位置附近（差异<2秒）才开始同步显示进度"], deletions: []),
                UpdateEntry(id: "v2.10.20", version: "2.10.20", date: "2026-09-06",
                    features: ["更新日志修复：每次启动自动合并内置新版本日志", "更新日志修复：新版本不再只显示一句话，显示完整新增/修复/删除内容"],
                    fixes: ["修复更新日志内容显示不全问题", "修复用户升级后新版本日志不加载问题（之前只在entries为空时加载内置数据）", "seek极端保护（继承v2.10.19）：5秒内时间观察者完全禁用，progress锁死不回退"], deletions: []),
                UpdateEntry(id: "v2.10.19", version: "2.10.19", date: "2026-09-06",
                    features: ["seek极端保护：5秒内时间观察者完全禁用（isSeeking+seekLockUntil双重锁）", "seek后progress锁死为目标值，任何代码不能修改", "只有seek成功且差异<1秒才提前解除保护", "5秒后强制解除，差异>3秒保持目标值不回退"],
                    fixes: ["彻底修复点击歌词/±15秒/拖动进度条后进度回退问题", "去掉seek前暂停（回退根因）", "去掉轮询状态机，恢复AVPlayer原生seek"], deletions: []),
                UpdateEntry(id: "v2.10.18", version: "2.10.18", date: "2026-09-06",
                    features: [],
                    fixes: ["seek彻底简化：去掉seek前暂停（回退根因）", "去掉轮询状态机，恢复AVPlayer原生seek completion handler", "保留isSeeking+差异>3秒不覆盖两层保护"], deletions: []),
                UpdateEntry(id: "v2.10.17", version: "2.10.17", date: "2026-09-05",
                    features: [],
                    fixes: ["恢复时间观察者差异>3秒不覆盖逻辑", "超时后progress强制保持为targetSeekTime不被实际时间覆盖"], deletions: []),
        ]
    }

    private init() {
        load()
        // 内置初始更新日志
        // 每次启动都合并内置新日志（不只是空时加载）
        let builtIn = Self.builtInEntries
        // 合并：内置有但entries中没有的版本，添加进去
        let existingVersions = Set(entries.map { $0.version })
        for built in builtIn {
            if !existingVersions.contains(built.version) {
                entries.append(built)
            }
        }
        // 按版本号降序排序
        entries.sort { e1, e2 in
            let p1 = e1.version.split(separator: ".").compactMap { Int($0) }
            let p2 = e2.version.split(separator: ".").compactMap { Int($0) }
            for i in 0..<max(p1.count, p2.count) {
                let v1 = i < p1.count ? p1[i] : 0
                let v2 = i < p2.count ? p2[i] : 0
                if v1 != v2 { return v1 > v2 }
            }
            return false
        }
        save()
        latestEntry = entries.first
    }

    /// 启动后调用（不在 init 中修改 @Published，避免 iOS17 崩溃）
    func startupCheck() {
        autoCheckVersion()
        // 真正去 GitHub 检查是否有新版本
        checkForUpdatesManually()
    }

    /// 自动检测当前 App 版本，若比记录新则自动添加更新日志
    private func autoCheckVersion() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        let hasVersion = entries.contains { $0.version == currentVersion }
        guard !hasVersion else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        // 自动添加的版本日志：检查是否有内置详细数据
        let builtInDetails = Self.builtInEntries.first { $0.version == currentVersion }
        let entry = UpdateEntry(
            id: "v\(currentVersion)",
            version: currentVersion,
            date: fmt.string(from: Date()),
            features: builtInDetails?.features ?? ["版本 \(currentVersion) 更新"],
            fixes: builtInDetails?.fixes ?? ["性能优化与稳定性改进"],
            deletions: builtInDetails?.deletions ?? []
        )
        entries.insert(entry, at: 0)
        latestEntry = entries.first
        save()
    }

    /// 手动检查更新：从 GitHub 获取最新 release，只在比当前版本新时弹窗
    func checkForUpdatesManually(completion: ((Bool, String?) -> Void)? = nil) {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        guard let url = URL(string: "https://api.github.com/repos/1314a520al-cyber/music/releases/latest") else {
            completion?(false, "检查失败")
            return
        }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                DispatchQueue.main.async { completion?(false, "网络错误") }
                return
            }
            let latestVersion = tag.replacingOccurrences(of: "v", with: "")
            let isNewer = self.isVersion(latestVersion, greaterThan: currentVersion)
            DispatchQueue.main.async {
                if isNewer {
                    // 构建更新条目
                    let body = json["body"] as? String ?? ""
                    let features = self.extractSection(body, prefix: "### 新增")
                    let fixes = self.extractSection(body, prefix: "### 修复")
                    let deletions = self.extractSection(body, prefix: "### 删除")
                    let entry = UpdateEntry(id: tag, version: latestVersion, date: json["published_at"] as? String ?? "", features: features, fixes: fixes, deletions: deletions)
                    self.latestEntry = entry
                    self.showUpdatePrompt = true
                    completion?(true, "发现新版本 \(latestVersion)")
                } else {
                    completion?(false, "已是最新版本（\(currentVersion)）")
                }
            }
        }.resume()
    }

    private func isVersion(_ a: String, greaterThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va != vb { return va > vb }
        }
        return false
    }

    private func extractSection(_ body: String, prefix: String) -> [String] {
        guard let range = body.range(of: prefix) else { return [] }
        var section = String(body[range.upperBound...])
        if let nextRange = section.range(of: "### ") {
            section = String(section[..<nextRange.lowerBound])
        }
        return section.split(separator: Character("\n")).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") { return String(trimmed.dropFirst(2)) }
            return nil
        }
    }

    /// 启动时检查本地更新日志（仅用于显示更新日志页面，不触发更新弹窗）
    func checkForUpdates() {
        // 更新弹窗只由 checkForUpdatesManually（GitHub 检查）触发
        // 此方法仅用于本地日志记录对比
    }

    func markSeen() {
        if let latest = entries.first {
            UserDefaults.standard.set(latest.version, forKey: lastSeenKey)
        }
        showUpdatePrompt = false
    }

    /// 添加新版本更新记录（每次发版调用）
    func addEntry(version: String, features: [String], fixes: [String], deletions: [String] = []) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let entry = UpdateEntry(id: "v\(version)", version: version, date: fmt.string(from: Date()), features: Array(NSOrderedSet(array: features).array as? [String] ?? features), fixes: Array(NSOrderedSet(array: fixes).array as? [String] ?? fixes), deletions: deletions)
        if let idx = entries.firstIndex(where: { $0.version == version }) {
            entries[idx] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        latestEntry = entries.first
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([UpdateEntry].self, from: data) else { return }
        entries = arr
        latestEntry = arr.first
    }
}
