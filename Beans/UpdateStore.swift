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

    private init() {
        load()
        // 内置初始更新日志
        if entries.isEmpty {
            entries = [
                UpdateEntry(id: "v2.9.3", version: "2.9.3", date: "2026-09-04",
                    features: ["听歌统计页面（本周时长/最爱歌手/最爱歌曲）", "意见反馈入口", "播放队列管理入口", "番茄钟专注模式入口"],
                    fixes: ["修复歌词点击跳转下一首歌的bug", "修复洛雪音乐同步协议（Authorization header）", "修复功能入口不可见问题"], deletions: ["网盘登录（迅雷/夸克/UC）"]),
                UpdateEntry(id: "v2.9.2", version: "2.9.2", date: "2026-09-04",
                    features: ["播放队列管理（调整顺序/移除歌曲）", "记忆播放进度（长音频自动续播）", "歌单内排序（时间/歌名/歌手/专辑/时长）", "歌单内搜索", "自定义歌单封面", "歌单备注", "搜索历史", "热门搜索", "下载管理页面"],
                    fixes: ["修复队列重排编译错误", "修复搜索历史record方法"], deletions: []),
                UpdateEntry(id: "v2.9.1", version: "2.9.1", date: "2026-09-04",
                    features: ["番茄钟专注模式（25+5分钟）", "重复歌曲检测", "每周听歌报告", "听歌数据自动追踪"],
                    fixes: ["修复导入音源没有效果（自定义音源置顶+测试按钮+更多格式支持）", "修复音源导入后不可见问题"], deletions: []),
                UpdateEntry(id: "v2.9.0", version: "2.9.0", date: "2026-09-04",
                    features: ["相似歌曲推荐", "智能电台（连续播放相似曲目）", "情境推荐（早晨/通勤/运动/睡前）", "批量操作（多选加入歌单/收藏/下载）", "交叉淡入淡出", "分享歌曲卡片（封面+歌词）", "低流量模式（64kbps）"],
                    fixes: ["修复QQ音源播放", "修复酷狗排行榜只显示12首", "修复酷狗专辑不加载"], deletions: []),
                UpdateEntry(id: "v2.8.0", version: "2.8.0", date: "2026-09-04",
                    features: ["黑胶唱盘样式封面", "播放页下滑关闭动效", "内置免费音源CeruMusic和全豆要聚合", "自定义导入音源（链接/文本/JS文件）", "触动反馈开关", "启动自动播放"],
                    fixes: ["修复更新检测错误（真正调用GitHub API）", "性能优化减少卡顿"], deletions: []),
                UpdateEntry(id: "v2.7.2", version: "2.7.2", date: "2026-09-04",
                    features: ["WebDAV远程备份（猫咪图标弹窗）", "云端歌曲自动识别封面和歌词"],
                    fixes: ["修复更新检测推送旧版本问题"], deletions: []),
                UpdateEntry(id: "v2.7.1", version: "2.7.1", date: "2026-09-04",
                    features: ["音效引擎打通播放器（实时切换音效）", "云端音乐页面（四大分类折叠：网盘/QQ/网易云/酷狗）"],
                    fixes: ["修复音效选择后不生效问题"], deletions: []),
                UpdateEntry(id: "v2.7.0", version: "2.7.0", date: "2026-09-04",
                    features: ["洛雪音乐同步（上传/下载歌单和收藏）", "我的页面歌单同步入口"],
                    fixes: ["修复同步地址和密码配置"], deletions: []),
                UpdateEntry(id: "v2.6.6", version: "2.6.6", date: "2026-09-03",
                    features: ["更新弹窗自动添加当前版本记录", "等级系统改用NotificationCenter监听播放状态", "更新弹窗紧凑化布局", "新增5个免费高品音源"],
                    fixes: ["修复更新弹窗显示旧版本问题", "修复等级听歌不涨经验问题", "修复更新弹窗太大太乱"], deletions: []),
                UpdateEntry(id: "v2.6.5", version: "2.6.5", date: "2026-09-03",
                    features: ["漂亮的自定义更新弹窗（渐变头部+三段式+三按钮）", "头像加载失败/加载中状态处理", "小组件美化（光晕+封面阴影+均衡器条）", "新增6个免费音源"],
                    fixes: ["修复等级系统不显示不同步", "修复我的页面头像加载不出来", "修复我的页面三账号冗余显示"], deletions: ["我的页面三平台账号独立显示（移入账号管理）"]),
                UpdateEntry(id: "v2.6.4", version: "2.6.4", date: "2026-09-03",
                    features: ["播放页更多操作面板重设计为4列网格+渐变图标", "新增5个免费音源", "播放器设置页加实时预览卡片"],
                    fixes: ["进度更新阈值0.01→0.02减少50%重渲染"], deletions: []),
                UpdateEntry(id: "v2.6.3", version: "2.6.3", date: "2026-09-03",
                    features: ["功能区加网盘管理入口", "新增4个免费无损音源"],
                    fixes: ["修复更新日志和云端歌曲点不开"], deletions: []),
                UpdateEntry(id: "v2.6.2", version: "2.6.2", date: "2026-09-03",
                    features: ["新增6个免费高品音源"],
                    fixes: ["修复更新日志和云端歌曲点不开"], deletions: []),
                UpdateEntry(id: "v2.6.1", version: "2.6.1", date: "2026-09-03",
                    features: ["VIP提示精简为歌名+音源名", "我的页面功能默认收起", "新增5个免费音源", "音游判定线上移+频谱条避底部"],
                    fixes: ["修复音游暂停停止计时"], deletions: []),
                UpdateEntry(id: "v2.6.0", version: "2.6.0", date: "2026-09-03",
                    features: ["更新弹窗改用系统alert彻底解决闪退"],
                    fixes: ["彻底修复UpdatePromptView ForEach重复ID导致的SIGTRAP闪退"], deletions: ["自定义UpdatePromptView（临时移除）"]),
                UpdateEntry(id: "v2.5.0", version: "2.5.0", date: "2026-09-03",
                    features: ["网盘管理（迅雷/夸克/UC WebView登录）", "Web功能备份/识别歌曲", "证书签名更新功能", "推送更新三按钮"],
                    fixes: ["适配iOS16-iOS27", "修复启动闪退"], deletions: []),
                UpdateEntry(id: "v2.4.0", version: "2.4.0", date: "2026-09-02",
                    features: ["酷狗音乐源集成", "主页面右上角漫游和心动模式", "启动动画", "iPhone小组件"],
                    fixes: ["修复首页闪退", "优化启动性能"], deletions: []),
                UpdateEntry(id: "v2.3.0", version: "2.3.0", date: "2026-09-02",
                    features: ["评论区发布同步", "等级系统完善", "缓存分类管理"],
                    fixes: ["优化列表渲染性能"], deletions: []),
                UpdateEntry(id: "v2.2.0", version: "2.2.0", date: "2026-09-02",
                    features: ["下载歌曲功能", "歌词点击跳转播放", "歌词大小调节", "更多皮肤/歌词/进度条效果"],
                    fixes: ["修复VIP歌曲无法播放", "修复收藏歌单"], deletions: []),
                UpdateEntry(id: "v2.1.0", version: "2.1.0", date: "2026-09-02",
                    features: ["音游全面适配手机屏幕（安全区/动态尺寸/不再硬编码）", "评论区UI优化：卡片式我的评论+发布后自动收起键盘", "账号管理页新增我的评论历史（折叠）", "最近播放支持折叠展开", "新增更新日志页面+启动自动推送更新提示", "设置全部持久化，下次打开保持上次设置"],
                    fixes: ["修复等级系统不升级问题（PlayerManager.shared弱引用改为强引用）", "修复音游在刘海屏显示不全问题", "优化评论列表视觉样式"], deletions: []),
                UpdateEntry(id: "v2.0.0", version: "2.0.0", date: "2026-09-02",
                    features: ["节奏音游全面重写：FFT频谱/震屏/长键激光/金币Bonus/Fever暴走/S-A-B-C评级", "播放页新增可见评论按钮", "评论区支持发布评论并同步到网易云", "三平台评论查看（网易云/QQ/酷狗）"],
                    fixes: ["音游渲染改用Canvas提升性能", "歌词阴影优化减少GPU开销"], deletions: []),
                UpdateEntry(id: "v1.9.1", version: "1.9.1", date: "2026-09-02",
                    features: ["播放页右上角新增可见更多操作按钮", "等级/听歌统计移入账号管理页", "新增听歌排行（前三名金银铜奖牌）"],
                    fixes: ["修复更多按钮藏在手势里找不到的问题", "歌词双层阴影合并为一层"], deletions: []),
                UpdateEntry(id: "v1.9.0", version: "1.9.0", date: "2026-09-01",
                    features: ["听歌时长+等级系统（7级称号）", "网易云听歌打卡同步", "缓存分类管理（7类占比/上限/可折叠）", "我的页面排版可拖拽排序"],
                    fixes: ["修复scrobble方法位置错误", "修复theme.accent类型不匹配"], deletions: []),
                UpdateEntry(id: "v1.8.0", version: "1.8.0", date: "2026-08-31",
                    features: ["新增节奏音游（Fever/长键/金币/连击/粒子）", "歌词效果扩至23种", "进度条样式扩至11种", "我的功能区可折叠"],
                    fixes: ["修复歌词点击0.35秒延迟", "修复iOS17 onTapGesture兼容性"], deletions: []),
                UpdateEntry(id: "v1.7.1", version: "1.7.1", date: "2026-08-30",
                    features: ["我的页面功能区正常渲染"],
                    fixes: ["修复featuresGrid定义但未渲染导致功能找不到", "清理README开源引用"], deletions: ["MIT LICENSE"]),
                UpdateEntry(id: "v1.7.0", version: "1.7.0", date: "2026-08-29",
                    features: ["下载文件夹系统", "pyncmd免费音源", "36种音效/10混响/7速度", "13种歌词效果"],
                    fixes: ["修复DownloadFolderView条件ToolbarItem", "修复SongSource.displayName不存在"], deletions: []),
                UpdateEntry(id: "v1.0.0", version: "1.0.0", date: "2026-08-20",
                    features: ["Music 音乐播放器首次发布", "自定义音源+卡密", "删除更新/社群/歌单广场", "换图标/赞赏码/清缓存"],
                    fixes: [], deletions: [])
            ]
            save()
        }
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
        let entry = UpdateEntry(
            id: "v\(currentVersion)",
            version: currentVersion,
            date: fmt.string(from: Date()),
            features: ["版本 \(currentVersion) 更新"],
            fixes: ["性能优化与稳定性改进"],
            deletions: []
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
