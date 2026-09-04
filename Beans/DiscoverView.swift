import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared

    @State private var topLists: [TopList] = []
    @State private var dailySongs: [Song] = []

    @State private var loading = true
    @State private var errorMessage: String?
    @State private var selectedTopList: TopList?
    @State private var showDailyList = false
    @State private var showSectionSort = false
    @State private var homeOrder = SectionOrderStore.load(SectionOrderStore.homeKey, defaults: SectionOrderStore.homeDefaults)

    /// 当前主页可排序的板块：每日推荐 / 排行榜
    private var availableSections: [String] {
        SectionOrderStore.homeDefaults
    }
    /// 首页数据源：记住上次选择，下次打开仍保持该平台（默认网易云）
    @AppStorage("beans.homeSource") private var homeSourceRaw = SearchProvider.netease.rawValue
    private var homeProviders: [SearchProvider] { platformPrefs.enabledSearchProviders }
    /// 首页数据源：网易云 / QQ音乐（与搜索页同一控件样式）
    private var source: SearchProvider {
        guard let saved = SearchProvider(rawValue: homeSourceRaw), homeProviders.contains(saved) else {
            return homeProviders.first ?? .netease
        }
        return saved
    }

    @State private var qqTopLists: [QQTopInfo] = []
    @State private var selectedQQTopList: QQTopInfo?
    @State private var kugouTopLists: [KugouTopInfo] = []
    @State private var selectedKugouTopList: KugouTopInfo?
    /// 排行榜展开状态：收起显示前 3，展开显示前 10
    @State private var ranksExpanded = true
    /// 首页加载去重：SwiftUI 视图刷新时 .task 可能被重复触发，避免网络请求风暴。
    @State private var activeLoadKey: String?
    @State private var lastLoadedKey = ""
    @State private var lastLoadedAt = Date.distantPast
    @State private var isRoaming = false
    @State private var isHeartMode = false
    @State private var modeLoading = false
    /// 首次启动免责声明：确认进入后若加载失败自动刷新
    @AppStorage("beans.disclaimerAccepted") private var disclaimerAccepted = false
    /// 官方歌单分类列表

    var body: some View {
        let _ = theme.accent
        ZStack {
            // 主页背景：壁纸/背景色永远在发现页生效（homeMode），同步开启时其他页面也生效
            GlassBackdrop(customColor: theme.customBackground, homeMode: true)
            // 实例级 UITabBar 清透风格（固定全透明，无需调节）
            TabBarAppearanceConfigurator()
            ScrollView {
                ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 26) {
                    header
                    providerPicker
                    if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            Task { await load(force: true) }
                        }
                    } else if loading {
                        LoadingStateView()
                    } else {
                        // 板块按用户自定义顺序渲染（可拖拽排序）
                        ForEach(Array(homeOrder.filter { availableSections.contains($0) }.enumerated()), id: \.offset) { _, key in
                            switch key {
                            case "每日推荐":
                                if !dailySongs.isEmpty { dailySection.sectionEntrance(delay: 0) }
                            case "排行榜":
                                if hasRankData { topListsSection.sectionEntrance(delay: 0.08) }
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 190)
                }
            }
            .refreshable {
                await load(force: true)
            }
            .beansScrollIndicatorsHidden()
            .task(id: source) {
                await load(force: false)
            }
            .onAppear {
                guard let saved = SearchProvider(rawValue: homeSourceRaw), homeProviders.contains(saved) else {
                    homeSourceRaw = (homeProviders.first ?? .netease).rawValue
                    return
                }
            }
            .onReceive(platformPrefs.changes) { _ in
                let next = platformPrefs.ensureVisible(source)
                if next != source {
                    homeSourceRaw = next.rawValue
                }
            }
            .onChange(of: source) { _ in
                homeOrder = SectionOrderStore.load(SectionOrderStore.homeKey, defaults: availableSections)
            }
            .onChange(of: disclaimerAccepted) { accepted in
                // 免责声明确认进入后：若首页加载失败则自动刷新（无需手动下拉）
                if accepted, errorMessage != nil {
                    Task { await load(force: true) }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .beansNeteaseLoginDidUpdate)) { _ in
                guard platformPrefs.isEnabled(SearchProvider.netease) else { return }
                reloadAfterLoginUpdate(.netease)
            }
            .onReceive(NotificationCenter.default.publisher(for: .beansQQLoginDidUpdate)) { _ in
                guard platformPrefs.isEnabled(SearchProvider.qq) else { return }
                reloadAfterLoginUpdate(.qq)
            }
            .onReceive(NotificationCenter.default.publisher(for: .beansKugouLoginDidUpdate)) { _ in
                guard platformPrefs.isEnabled(SearchProvider.kugou) else { return }
                reloadAfterLoginUpdate(.kugou)
            }
            .sheet(item: $selectedTopList) { topList in
                TopListDetailView(topList: topList)
                    .environmentObject(player)
                    .environmentObject(auth)
            }
            .sheet(item: $selectedQQTopList) { info in
                QQTopListDetailView(topID: info.id, name: info.name)
                    .environmentObject(player)
                    .environmentObject(auth)
            }
            .sheet(item: $selectedKugouTopList) { info in
                KugouTopListDetailView(topList: info)
                    .environmentObject(player)
            }
            .sheet(isPresented: $showDailyList) {
                DailySongsSheet(songs: dailySongs)
                    .environmentObject(player)
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showSectionSort) {
                SectionOrderSheet(title: "主页板块排序", sections: availableSections, order: $homeOrder)
                    .onDisappear { SectionOrderStore.save(SectionOrderStore.homeKey, homeOrder) }
            }
        }
    }

    /// 顶部问候区：大标题 + 刷新按钮
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(BeansFont.appFont(30, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Text(auth.user?.nickname ?? "发现好音乐")
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                // 心动模式
                Button {
                    BeansHaptics.tap()
                    isHeartMode.toggle()
                    if isHeartMode {
                        isRoaming = false
                        ToastCenter.shared.show("心动模式：播放相似歌曲")
                        Task { await startHeartMode() }
                    } else {
                        ToastCenter.shared.show("已退出心动模式")
                    }
                } label: {
                    Image(systemName: isHeartMode ? "heart.circle.fill" : "heart.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isHeartMode ? Color(red: 0.95, green: 0.33, blue: 0.42) : Color.beansLabel)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle().fill(isHeartMode ? Color(red: 0.95, green: 0.33, blue: 0.42).opacity(0.15) : Color.primary.opacity(0.06))
                        }
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.9))
                .disabled(modeLoading)
                // 漫游模式
                Button {
                    BeansHaptics.tap()
                    isRoaming.toggle()
                    if isRoaming {
                        isHeartMode = false
                        ToastCenter.shared.show("漫游模式：随机发现好音乐")
                        Task { await startRoaming() }
                    } else {
                        ToastCenter.shared.show("已退出漫游模式")
                    }
                } label: {
                    Image(systemName: isRoaming ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isRoaming ? Color.beansAmber : Color.beansLabel)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle().fill(isRoaming ? Color.beansAmber.opacity(0.15) : Color.primary.opacity(0.06))
                        }
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.9))
                .disabled(modeLoading)
            }
        }
        .padding(.top, 8)
    }

    /// 平台选择（网易云 / QQ音乐 / 酷狗音乐，样式与搜索页一致）
    private var providerPicker: some View {
        HStack(spacing: 4) {
            ForEach(homeProviders) { p in
                Button {
                    BeansHaptics.tap()
                    if source != p { homeSourceRaw = p.rawValue }
                } label: {
                    HStack(spacing: 6) {
                        if let imageName = p.brandImageName {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: p.icon)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(p.rawValue)
                            .font(BeansFont.appFont(13, .semibold))
                    }
                    .foregroundStyle(source == p ? Color.white : Color.beansComment)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if source == p {
                            Capsule().fill(p.tint)
                        } else {
                            Capsule().fill(.clear)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
                        BeansGlass(shape: Capsule())
        }
        .clipShape(Capsule())
        .beansCardShadow(radius: 6, y: 2)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }


    /// 每日推荐封面右下角播放状态：当前播放中显示动态指示器，暂停显示暂停，其余显示播放
    @ViewBuilder
    private func dailyPlayStateBadge(for song: Song) -> some View {
        let isCurrent = player.currentSong?.identityKey == song.identityKey
        ZStack {
            if isCurrent && player.isPlaying {
                NowPlayingIndicator()
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.45), in: Circle())
            } else {
                Image(systemName: isCurrent ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.45), in: Circle())
            }
        }
        .padding(7)
    }

    /// 网易云排行榜：全部榜单保留，热歌榜置顶
    private var neteaseTopLists: [TopList] {
        var list = topLists
        if let hot = list.first(where: { $0.name.contains("热歌榜") }),
           let idx = list.firstIndex(where: { $0.id == hot.id }), idx != 0 {
            list.remove(at: idx)
            list.insert(hot, at: 0)
        }
        return list
    }

    /// 每平台排行榜最多 10 个（收起只显示前 3，展开显示前 10）
    private var visibleRankCount: Int {
        switch source {
        case .netease: return neteaseTopLists.count
        case .qq: return qqTopLists.count
        case .kugou: return kugouTopLists.count
        }
    }

    private var displayedRankCount: Int {
        ranksExpanded ? min(visibleRankCount, 10) : min(visibleRankCount, 3)
    }

    /// 当前平台是否有排行榜数据（网易云用 topLists，QQ 用 qqTopLists）
    private var hasRankData: Bool {
        switch source {
        case .netease: return !topLists.isEmpty
        case .qq: return !qqTopLists.isEmpty
        case .kugou: return !kugouTopLists.isEmpty
        }
    }

    // MARK: - 排行榜（竖排行列表）

    private var topListsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "排行榜")
            VStack(spacing: 0) {
                if ranksExpanded {
                    rankToggleButton(label: "收起", icon: "chevron.up")
                    Divider().overlay(Color.beansComment.opacity(0.12))
                }
                rankRowsContent
                if !ranksExpanded, visibleRankCount > 3 {
                    rankToggleButton(label: "展开全部（\(min(visibleRankCount, 10))）", icon: "chevron.down")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.06))
                    .background {
                        BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .beansCardShadow(radius: 9, y: 3)
            .id("rankTopSection")
        }
    }

    /// 排行榜行列表（按平台渲染）
    @ViewBuilder
    private var rankRowsContent: some View {
        if source == .netease {
            ForEach(Array(neteaseTopLists.prefix(displayedRankCount).enumerated()), id: \.element.id) { index, topList in
                rankRow(index: index, name: topList.name, subtitle: topList.updateFrequency, coverURL: topList.coverURL) {
                    BeansHaptics.tap()
                    selectedTopList = topList
                }
                Divider().overlay(Color.beansComment.opacity(0.12))
            }
        } else if source == .qq {
            ForEach(Array(qqTopLists.prefix(displayedRankCount).enumerated()), id: \.element.id) { index, info in
                rankRow(index: index, name: info.name, subtitle: "QQ 峰尖榜", coverURL: info.coverURL) {
                    BeansHaptics.tap()
                    selectedQQTopList = info
                }
                Divider().overlay(Color.beansComment.opacity(0.12))
            }
        } else if source == .kugou {
            ForEach(Array(kugouTopLists.prefix(displayedRankCount).enumerated()), id: \.element.id) { index, info in
                rankRow(index: index, name: info.name, subtitle: info.updateFrequency, coverURL: info.coverURL) {
                    BeansHaptics.tap()
                    selectedKugouTopList = info
                }
                Divider().overlay(Color.beansComment.opacity(0.12))
            }
        } else {
            EmptyView()
        }
    }

    /// 展开 / 收起切换按钮
    private func rankToggleButton(label: String, icon: String) -> some View {
        Button {
            BeansHaptics.select()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) { ranksExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(BeansFont.appFont(13, .medium))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.beansAmber)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rankRow(index: Int, name: String, subtitle: String, coverURL: URL?, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(BeansFont.appFont(16, .bold, .rounded))
                    .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansComment)
                    .frame(width: 24)
                CoverImage(url: coverURL, size: 52, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// QQ 峰尖榜占位渐变（保留备用）
    private func qqRankGradient(_ name: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.35, green: 0.55, blue: 0.95), Color(red: 0.20, green: 0.30, blue: 0.65)],
            [Color(red: 0.95, green: 0.42, blue: 0.36), Color(red: 0.70, green: 0.18, blue: 0.20)],
            [Color(red: 0.20, green: 0.78, blue: 0.62), Color(red: 0.08, green: 0.52, blue: 0.44)],
            [Color(red: 0.92, green: 0.62, blue: 0.25), Color(red: 0.72, green: 0.38, blue: 0.12)],
            [Color(red: 0.62, green: 0.45, blue: 0.90), Color(red: 0.40, green: 0.25, blue: 0.68)],
            [Color(red: 0.30, green: 0.70, blue: 0.85), Color(red: 0.16, green: 0.45, blue: 0.65)]
        ]
        let seed = abs(name.hashValue) % palettes.count
        return LinearGradient(colors: palettes[seed], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - 每日推荐（横滑歌曲卡 + 播放）

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "每日推荐", trailing: "查看全部") {
                BeansHaptics.tap()
                showDailyList = true
            }
            // 横滑歌曲卡：每日推荐前 8 首
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(dailySongs.prefix(8).enumerated()), id: \.element.identityKey) { index, song in
                        Button {
                            BeansHaptics.tap()
                            player.play(songs: dailySongs, startAt: index)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                CoverImage(url: song.coverURL, size: 108, cornerRadius: 16)
                                    .overlay(alignment: .topLeading) {
                                        if song.isVIP {
                                            Text("VIP")
                                                .font(BeansFont.appFont(9, .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(Capsule().fill(Color(red: 0.93, green: 0.25, blue: 0.22)))
                                                .padding(6)
                                        }
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        dailyPlayStateBadge(for: song)
                                    }
                                Text(song.name)
                                    .font(BeansFont.appFont(12, .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                    .frame(width: 108, alignment: .leading)
                                Text(song.artists.isEmpty ? song.album : song.artists)
                                    .font(BeansFont.appFont(10))
                                    .foregroundStyle(Color.beansComment)
                                    .lineLimit(1)
                                    .frame(width: 108, alignment: .leading)
                            }
                        }
                        .buttonStyle(GlassPressButtonStyle(scale: 0.94))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 动作

    @MainActor
    private func load(force: Bool = false) async {
        let requestedSource = source
        let loadKey = requestedSource.rawValue
        if activeLoadKey == loadKey { return }
        if !force, lastLoadedKey == loadKey,
           Date().timeIntervalSince(lastLoadedAt) < 30, hasAnyData {
            loading = false; errorMessage = nil; return
        }
        activeLoadKey = loadKey
        defer { if activeLoadKey == loadKey { activeLoadKey = nil } }
        loading = true
        errorMessage = nil
        do {
            let snapshot = try await fetchSnapshot(for: requestedSource)
            guard !Task.isCancelled, requestedSource == source else { return }
            apply(snapshot)
            loading = false
            errorMessage = nil
            lastLoadedKey = loadKey
            lastLoadedAt = Date()
        } catch {
            guard !Task.isCancelled, requestedSource == source else { return }
            loading = false
            if !hasAnyData { errorMessage = "加载失败，请下拉刷新" }
        }
    }

    private func reloadAfterLoginUpdate(_ provider: SearchProvider) {
        if source == provider {
            Task { await load(force: true) }
        } else {
            homeSourceRaw = provider.rawValue
        }
    }

    // MARK: - 心动模式 / 漫游模式

    /// 心动模式：基于当前播放歌曲搜索相似歌曲并播放
    private func startHeartMode() async {
        modeLoading = true
        defer { Task { @MainActor in modeLoading = false } }
        let keyword: String
        if let current = player.currentSong {
            keyword = ([current.name, current.artists].filter { !$0.isEmpty }).joined(separator: " ")
        } else {
            keyword = "热门歌曲"
        }
        do {
            var songs: [Song] = []
            switch source {
            case .netease:
                songs = try await NetEaseAPI.shared.search(keyword: keyword, limit: 30)
            case .qq:
                songs = try await QQMusicAPI.shared.searchSongs(keyword: keyword, limit: 30)
            case .kugou:
                songs = try await KugouMusicAPI.shared.searchSongs(keyword: keyword, limit: 30)
            }
            if !songs.isEmpty {
                await MainActor.run {
                    player.play(songs: songs, startAt: 0)
                    ToastCenter.shared.show("心动模式已开启，共 \(songs.count) 首")
                }
            } else {
                await MainActor.run {
                    isHeartMode = false
                    ToastCenter.shared.show("未找到相似歌曲")
                }
            }
        } catch {
            await MainActor.run {
                isHeartMode = false
                ToastCenter.shared.show("心动模式加载失败")
            }
        }
    }

    /// 漫游模式：随机关键词搜索，跨平台发现好音乐
    private func startRoaming() async {
        modeLoading = true
        defer { Task { @MainActor in modeLoading = false } }
        let keywords = ["流行金曲", "经典老歌", "轻音乐", "电子音乐", "摇滚", "民谣", "R&B", "嘻哈", "治愈系", "运动节奏"]
        let keyword = keywords.randomElement() ?? "热门歌曲"
        do {
            var songs: [Song] = []
            // 漫游模式：随机选一个平台搜索
            let platforms: [SearchProvider] = [.netease, .qq, .kugou].filter { platformPrefs.isEnabled($0) }
            let platform = platforms.randomElement() ?? source
            switch platform {
            case .netease:
                songs = try await NetEaseAPI.shared.search(keyword: keyword, limit: 30)
            case .qq:
                songs = try await QQMusicAPI.shared.searchSongs(keyword: keyword, limit: 30)
            case .kugou:
                songs = try await KugouMusicAPI.shared.searchSongs(keyword: keyword, limit: 30)
            }
            if !songs.isEmpty {
                await MainActor.run {
                    player.play(songs: songs, startAt: Int.random(in: 0..<songs.count))
                    ToastCenter.shared.show("漫游到「\(keyword)」，共 \(songs.count) 首")
                }
            } else {
                await MainActor.run {
                    isRoaming = false
                    ToastCenter.shared.show("漫游失败，再试一次")
                }
            }
        } catch {
            await MainActor.run {
                isRoaming = false
                ToastCenter.shared.show("漫游加载失败")
            }
        }
    }

    private func fetchSnapshot(for source: SearchProvider) async throws -> DiscoverCache.Snapshot {
        // 10秒超时，防止API挂起导致一直加载
        try await withThrowingTaskGroup(of: DiscoverCache.Snapshot.self) { group in
            group.addTask {
                var snapshot = DiscoverCache.Snapshot()
                snapshot.savedAt = Date()
                switch source {
                case .qq:
                    async let a = QQMusicAPI.shared.recommendSongs(limit: 10)
                    async let b = QQMusicAPI.shared.topLists()
                    let (dr, tl) = try await (a, b)
                    snapshot.dailySongs = dr
                    snapshot.qqTopLists = Array(tl.prefix(5))
                case .netease:
                    async let a = NetEaseAPI.shared.topLists()
                    async let b = NetEaseAPI.shared.dailyRecommend()
                    let (tl, dr) = try await (a, b)
                    snapshot.topLists = Array(tl.prefix(5))
                    snapshot.dailySongs = Array(dr.prefix(8))
                case .kugou:
                    async let songs = KugouMusicAPI.shared.searchSongs(keyword: "热门歌曲", limit: 10)
                    async let ranks = KugouMusicAPI.shared.topLists(limit: 5)
                    let (daily, top) = try await (songs, ranks)
                    snapshot.dailySongs = daily
                    snapshot.kugouTopLists = top
                }
                return snapshot
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                struct FetchTimeout: Error {}
                throw FetchTimeout()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func apply(_ snapshot: DiscoverCache.Snapshot) {
        // 严格限制数量，避免大量封面图同时加载导致内存压力闪退
        dailySongs = Array(snapshot.dailySongs.prefix(8))
        topLists = Array(snapshot.topLists.prefix(3))
        qqTopLists = Array(snapshot.qqTopLists.prefix(3))
        kugouTopLists = Array(snapshot.kugouTopLists.prefix(3))
    }

    private var hasAnyData: Bool {
        !dailySongs.isEmpty || !topLists.isEmpty
            || !qqTopLists.isEmpty || !kugouTopLists.isEmpty
    }
}

// MARK: - QQ 峰尖榜详情

struct QQTopListDetailView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore

    let topID: Int
    let name: String
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    List {
                        Section {
                            HStack(spacing: 12) {
                                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: 0)
                                }
                                GlassButton(title: "随机播放", systemName: "shuffle") {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: Int.random(in: 0..<filteredTracks.count))
                                }
                            }
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 8)
                        }
                        Section {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: filteredTracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                }
            }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索榜单歌曲")
        }
        .task { await load() }
    }

    private var filteredTracks: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return tracks }
        return tracks.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            tracks = try await QQMusicAPI.shared.topListSongs(topid: topID)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}

// MARK: - QQ 歌单内歌曲

struct QQPlaylistSongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore

    let playlist: Playlist
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    List {
                        Section {
                            HStack(spacing: 12) {
                                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: 0)
                                }
                                GlassButton(title: "随机播放", systemName: "shuffle") {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: Int.random(in: 0..<filteredTracks.count))
                                }
                            }
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 8)
                        }
                        Section {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: filteredTracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                }
            }
            }
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索歌单内歌曲")
        }
        .task { await load() }
    }

    private var filteredTracks: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return tracks }
        return tracks.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            tracks = try await QQMusicAPI.shared.playlistSongs(listID: playlist.id)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}

// MARK: - 每日推荐全部歌曲

struct DailySongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore

    let songs: [Song]
    @State private var searchText = ""

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if songs.isEmpty {
                    EmptyStateView(icon: "sparkles", text: "今日推荐加载中，下拉刷新试试")
                } else {
                    List {
                    Section {
                        HStack(spacing: 12) {
                            GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                                guard !filteredSongs.isEmpty else { return }
                                BeansHaptics.tap()
                                player.play(songs: filteredSongs, startAt: 0)
                            }
                            GlassButton(title: "随机播放", systemName: "shuffle") {
                                guard !filteredSongs.isEmpty else { return }
                                BeansHaptics.tap()
                                player.play(songs: filteredSongs, startAt: Int.random(in: 0..<filteredSongs.count))
                            }
                        }
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 8)
                    }
                    Section {
                        ForEach(Array(filteredSongs.enumerated()), id: \.element.identityKey) { index, song in
                            SongCell(song: song, glassRow: true) {
                                BeansHaptics.tap()
                                player.play(songs: filteredSongs, startAt: index)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .beansScrollContentBackgroundHidden()
                .listStyle(.plain)
                }
            }
            }
            .navigationTitle("今日推荐")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索每日推荐")
        }
    }

    private var filteredSongs: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return songs }
        return songs.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }
}
// MARK: - 排行榜详情

struct TopListDetailView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore

    let topList: TopList
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else {
                    List {
                        header
                        Section {
                            HStack(spacing: 12) {
                                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: 0)
                                }
                                GlassButton(title: "随机播放", systemName: "shuffle") {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: Int.random(in: 0..<filteredTracks.count))
                                }
                            }
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 8)
                        }
                        Section {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: filteredTracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                }
            }
            }
            .navigationTitle(topList.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索榜单歌曲")
        }
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CoverImage(url: topList.coverURL, size: 88, cornerRadius: 16)
            VStack(alignment: .leading, spacing: 6) {
                Text(topList.name)
                    .font(BeansFont.appFont(18, .bold))
                    .foregroundStyle(Color.beansLabel)
                Text(topList.updateFrequency)
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
                Text("\(tracks.count) 首")
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
            }
            Spacer()
        }
        .padding(14)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .beansCardShadow(radius: 8, y: 3)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var filteredTracks: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return tracks }
        return tracks.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            tracks = try await NetEaseAPI.shared.playlistTracks(id: topList.id)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}

// MARK: - 酷狗排行榜详情

struct KugouTopListDetailView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    let topList: KugouTopInfo
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load() }
                    }
                } else if tracks.isEmpty {
                    EmptyStateView(icon: "music.note.list", text: "该排行榜暂无歌曲")
                } else {
                    List {
                        header
                        Section {
                            HStack(spacing: 12) {
                                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: 0)
                                }
                                GlassButton(title: "随机播放", systemName: "shuffle") {
                                    guard !filteredTracks.isEmpty else { return }
                                    BeansHaptics.tap()
                                    player.play(songs: filteredTracks, startAt: Int.random(in: 0..<filteredTracks.count))
                                }
                            }
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 8)
                        }
                        Section {
                            ForEach(Array(filteredTracks.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: filteredTracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                }
            }
            }
            .navigationTitle(topList.name)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "搜索榜单歌曲")
        }
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CoverImage(url: topList.coverURL, size: 88, cornerRadius: 16)
            VStack(alignment: .leading, spacing: 6) {
                Text(topList.name)
                    .font(BeansFont.appFont(18, .bold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(2)
                if !topList.updateFrequency.isEmpty {
                    Text(topList.updateFrequency)
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Text("\(tracks.count) 首")
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .beansCardShadow(radius: 8, y: 3)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var filteredTracks: [Song] {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !kw.isEmpty else { return tracks }
        return tracks.filter { song in
            song.name.lowercased().contains(kw)
                || song.artists.lowercased().contains(kw)
                || song.album.lowercased().contains(kw)
        }
    }

    private func load() async {
        loading = true
        errorMessage = nil
        do {
            tracks = try await KugouMusicAPI.shared.rankSongs(rankID: topList.id)
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }
}
