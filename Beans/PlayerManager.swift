import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

enum PlayMode: String, CaseIterable, Identifiable {
    case sequential
    case repeatOne
    case shuffle

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sequential: return "repeat"
        case .repeatOne: return "repeat.1"
        case .shuffle: return "shuffle"
        }
    }

    var title: String {
        switch self {
        case .sequential: return "顺序播放"
        case .repeatOne: return "单曲循环"
        case .shuffle: return "随机播放"
        }
    }
}

final class PlaybackClock: ObservableObject {
    @Published private(set) var progress: Double = 0
    @Published private(set) var duration: Double = 0

    func update(progress: Double? = nil, duration: Double? = nil) {
        let apply = {
            if let progress, abs(progress - self.progress) > 0.02 {
                self.progress = progress
            }
            if let duration, abs(duration - self.duration) > 0.01 {
                self.duration = duration
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }
}

final class PlayerManager: NSObject, ObservableObject {
    /// 弱引用共享实例（由 App 入口注入，便于 Store 层访问播放状态）
    static var shared: PlayerManager?
    @Published var queue: [Song] = []
    @Published var currentIndex = 0
    @Published var isPlaying = false {
        didSet {
            NotificationCenter.default.post(name: .beansPlaybackStateDidChange, object: nil, userInfo: ["isPlaying": isPlaying])
        }
    }
    @Published var isBuffering = false
    @Published var loadFailed = false
    /// 切歌代次：防止旧歌的 URL 解析任务覆盖新歌（快速切歌时）
    private var loadGeneration = 0
    /// 当前播放任务的引用，用于切歌时取消旧的解析任务
    private var currentLoadTask: Task<Void, Never>?
    /// 播放失败重试次数（同一首歌最多重试 2 次，然后自动跳过）
    private var retryCountForCurrent = 0
    /// 缓冲超时计时器（超过 30 秒仍在缓冲则判定为加载失败）
    private var bufferingTimeoutTimer: Timer?
    let clock = PlaybackClock()
    var progress: Double = 0 {
        didSet { clock.update(progress: progress) }
    }
    var duration: Double = 0 {
        didSet { clock.update(duration: duration) }
    }
    @Published var playMode: PlayMode = .sequential
    @Published var rate: Double = AudioFxStore.shared.speed
    @Published var sleepTimerEndsAt: Date?
    @AppStorage("beans.crossfadeEnabled") private var crossfadeEnabled = false
    @AppStorage("beans.crossfadeDuration") private var crossfadeDuration = 2.0
    @Published var sleepTimerRemaining: Int = 0
    @Published var history: [Song] = []
    @Published var playCounts: [String: Int] = [:]

    private var player: AVPlayer?
    @Published var usingEffectEngine = false
    private var currentResolvedURL: URL?
    private var effectDownloadTask: URLSessionDownloadTask?
    private var effectTempFile: URL?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var playbackConfirmed = false
    private var pendingThirdPartyVIPNotice: ThirdPartyVIPNotice?
    private var sessionConfigured = false
    private var playOrder: [Int] = []
    private var orderPosition = 0
    private var sleepTimer: Timer?
    private var lastCountedSongID: String?
    private var wasPlayingBeforeInterruption = false
    private var lastPublishedProgress: Double = -1
    private var lastNowPlayingArtworkKey: String?
    private static let nowPlayingArtworkCache = NSCache<NSURL, UIImage>()

    private let historyKey = "beans.history"
    private let countsKey = "beans.playcounts"
    private let audioMixKey = "beans.audio.mixothers.v1"
    private let thirdPartyVIPNoticeKey = "beans.showThirdPartyVIPNotice"
    private let defaults = UserDefaults.standard

    private struct ThirdPartyVIPNotice {
        let songKey: String
        let message: String
    }

    var currentSong: Song? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    override init() {
        super.init()
        loadHistory()
        loadPlayCounts()
        observeInterruptions()
        observeRouteChanges()
        setupRemoteCommands()
    }

    /// 启动后配置音频系统（不在 init 中调用，避免 iOS17 初始化阶段崩溃）
    private func configureAudioSystem() {
        observeInterruptions()
        observeRouteChanges()
        setupRemoteCommands()
        // 音频会话配置交给 configureAudioSession（首次播放时自动调用）
    }

    // MARK: - 播放控制

    func play(songs: [Song], startAt index: Int = 0) {
        guard !songs.isEmpty else { return }
        queue = songs
        buildPlayOrder()
        jumpToOrderPosition(min(max(index, 0), songs.count - 1))
        syncToWidget()
    }

    /// 同步当前播放状态到桌面小组件（防御性：任何异常都不影响播放）
    private func syncToWidget() {
        // 主线程读取所有值，避免后台队列访问 @Published 属性导致线程竞争
        let songName = currentSong?.name ?? ""
        let artist = currentSong?.artists ?? ""
        let coverURL = currentSong?.coverURL?.absoluteString ?? ""
        let playing = isPlaying
        let hasSong = currentSong != nil
        DispatchQueue.global(qos: .utility).async {
            if !hasSong {
                WidgetSyncManager.shared.clearNowPlaying()
                return
            }
            WidgetSyncManager.shared.updateNowPlaying(
                songName: songName,
                artist: artist,
                coverURL: coverURL,
                isPlaying: playing
            )
        }
    }

    func playSong(_ song: Song, in context: [Song]) {
        play(songs: context, startAt: context.firstIndex(of: song) ?? 0)
    }

    /// 插队播放：把歌曲放到当前歌曲之后并立即播放
    func playNext(_ song: Song) {
        guard !queue.isEmpty else {
            play(songs: [song], startAt: 0)
            return
        }
        let insertAt = currentIndex + 1
        queue.insert(song, at: min(insertAt, queue.count))
        buildPlayOrder()
        jumpToOrderPosition(min(insertAt, queue.count - 1))
    }

    /// 播放本地文件（已下载的歌曲）
    func playLocalFile(url: URL, title: String, artist: String) {
        let song = Song(
            id: abs(url.path.hashValue),
            name: title,
            artists: artist,
            album: "本地下载",
            coverURL: nil,
            duration: 0,
            source: .netease,
            directURL: url,
            directSourceName: "本地"
        )
        play(songs: [song], startAt: 0)
    }

    func togglePlayPause() {
        if usingEffectEngine {
            if EffectAudioEngine.shared.isPlaying {
                EffectAudioEngine.shared.pause()
                isPlaying = false
            } else {
                EffectAudioEngine.shared.resume()
                isPlaying = true
            }
            updateNowPlaying()
            return
        }
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.playImmediately(atRate: Float(rate))
            isPlaying = true
        }
        updateNowPlaying()
    }

    func next(manual: Bool = true) {
        // 保存当前歌曲播放进度
        if let current = currentSong {
            PlaybackProgressStore.shared.saveProgress(songID: current.identityKey, position: progress)
        }
        if usingEffectEngine { EffectAudioEngine.shared.stop(); usingEffectEngine = false }
        guard !queue.isEmpty else { return }
        // 交叉淡入淡出：淡出当前歌曲
        if crossfadeEnabled, let player = player, isPlaying {
            player.volume = 1.0
            UIView.animate(withDuration: crossfadeDuration) {
                player.volume = 0
            }
        }
        if playMode == .repeatOne && manual {
            restartCurrent()
            return
        }
        advance()
        loadCurrent()
    }

    func previous() {
        if let current = currentSong {
            PlaybackProgressStore.shared.saveProgress(songID: current.identityKey, position: progress)
        }
        if usingEffectEngine { EffectAudioEngine.shared.stop(); usingEffectEngine = false }
        guard !queue.isEmpty else { return }
        // 直接切换到上一首（不再做“播放超过 3 秒先重头播放”的判断）
        if playMode == .shuffle {
            orderPosition = (orderPosition - 1 + playOrder.count) % playOrder.count
            currentIndex = playOrder[orderPosition]
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
        }
        loadCurrent()
    }

    func seek(to seconds: Double) {
        let clamped = max(0, min(seconds, max(duration, 0)))
        progress = clamped
        if usingEffectEngine {
            EffectAudioEngine.shared.seek(to: clamped)
            updateNowPlaying()
            return
        }
        // 用 seek 完成回调同步真实进度：避免暂停状态下拖动进度后，歌词定位与实际播放位置不一致
        player?.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            guard let self, finished else { return }
            let actual = self.player?.currentTime().seconds ?? clamped
            if abs(actual - self.progress) > 0.25 {
                self.progress = actual
            }
        }
        updateNowPlaying()
    }

    func seekBy(_ delta: Double) {
        seek(to: progress + delta)
    }

    func togglePlayMode() {
        switch playMode {
        case .sequential: playMode = .repeatOne
        case .repeatOne: playMode = .shuffle
        case .shuffle: playMode = .sequential
        }
        buildPlayOrder()
    }

    func setRate(_ newRate: Double) {
        rate = newRate
        if usingEffectEngine {
            EffectAudioEngine.shared.stop()
            if let file = effectTempFile {
                EffectAudioEngine.shared.play(url: file, rate: Float(newRate))
            }
        } else if isPlaying {
            player?.playImmediately(atRate: Float(newRate))
        }
        updateNowPlaying()
    }

    func playQueueIndex(_ index: Int) {
        guard queue.indices.contains(index) else { return }
        jumpToOrderPosition(index)
    }

    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index), queue.count > 1 else { return }
        let removedID = queue[index].id
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            currentIndex = min(currentIndex, queue.count - 1)
            loadCurrent()
        }
        buildPlayOrder(avoiding: removedID)
    }
    
    /// 兼容旧调用
    func removeQueueItem(at index: Int) {
        removeFromQueue(at: index)
    }
    
    /// 移动队列中的歌曲（用于手动调整顺序）
    func moveQueueItem(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        if let currentSong = currentSong {
            currentIndex = queue.firstIndex(where: { $0.identityKey == currentSong.identityKey }) ?? 0
        }
    }
    
    /// 清空队列（保留当前播放）
    func clearQueueExceptCurrent() {
        guard let current = currentSong else { return }
        queue = [current]
        currentIndex = 0
    }

    func retryCurrent() {
        loadFailed = false
        loadCurrent()
    }

    /// 删除单条播放历史（含持久化）
    func removeHistory(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard history.indices.contains(index) else { continue }
            history.remove(at: index)
        }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    /// 清空播放历史（含持久化）
    func clearHistory() {
        history.removeAll()
        defaults.removeObject(forKey: historyKey)
    }

    /// 清空队列，仅保留当前歌曲
    func clearQueue() {
        guard !queue.isEmpty else { return }
        if let current = currentSong {
            queue = [current]
            currentIndex = 0
        } else {
            queue = []
            currentIndex = 0
        }
        buildPlayOrder()
    }

    // MARK: - 睡眠定时

    func startSleepTimer(minutes: Int) {
        stopSleepTimer()
        sleepTimerEndsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerRemaining = minutes * 60
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let end = self.sleepTimerEndsAt else { return }
            let remain = Int(end.timeIntervalSinceNow)
            self.sleepTimerRemaining = max(0, remain)
            if remain <= 0 {
                self.stopSleepTimer()
                self.pausePlayback()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        sleepTimer = timer
    }

    func stopSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndsAt = nil
        sleepTimerRemaining = 0
    }

    var sleepTimerFormatted: String? {
        guard sleepTimerRemaining > 0 else { return nil }
        return String(format: "%d:%02d", sleepTimerRemaining / 60, sleepTimerRemaining % 60)
    }

    private func pausePlayback() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    // MARK: - 播放顺序

    private func buildPlayOrder(avoiding removedID: Int? = nil) {
        switch playMode {
        case .shuffle:
            var indices = Array(queue.indices).filter { $0 != removedID }
            indices.shuffle()
            playOrder = indices
            orderPosition = 0
        default:
            playOrder = Array(queue.indices)
            orderPosition = currentIndex
        }
    }

    private func advance() {
        switch playMode {
        case .shuffle:
            guard !playOrder.isEmpty else { return }
            orderPosition = (orderPosition + 1) % playOrder.count
            currentIndex = playOrder[orderPosition]
        default:
            currentIndex = (currentIndex + 1) % queue.count
            orderPosition = currentIndex
        }
    }

    private func jumpToOrderPosition(_ index: Int) {
        currentIndex = index
        if playMode == .shuffle {
            orderPosition = 0
            if let pos = playOrder.firstIndex(of: index) {
                orderPosition = pos
            }
        } else {
            orderPosition = index
        }
        loadCurrent()
    }

    // MARK: - 播放

    private func restartCurrent() {
        seek(to: 0)
        player?.playImmediately(atRate: Float(rate))
        isPlaying = true
        updateNowPlaying()
    }

    private func loadCurrent() {
        guard let song = currentSong else { return }
        // 取消旧的加载任务，防止快速切歌时旧任务覆盖新歌
        currentLoadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        retryCountForCurrent = 0
        // 切歌立即暂停旧音频，避免新歌加载期间旧歌继续播放造成"切歌卡住"感
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        stopBufferingTimeout()
        duration = song.duration
        progress = 0
        isPlaying = false
        isBuffering = true
        loadFailed = false
        pushHistory(song)
        let task = Task {
            var urlString: String?
            var resolvedThirdParty: UnblockService.Resolved?
            // 版权受限歌手（周杰伦）：允许第三方音源，但启用严格模式（歌名+歌手+时长三重匹配原唱，校验不过拒绝，绝不播放翻唱）
            // 免费听歌（灰色歌曲解锁）总开关：默认开启，优先使用内置预设音源兜底。
            let enableUnblock = defaults.object(forKey: "beans.enableUnblock") as? Bool ?? true
            let strictUnlock = shouldLockOfficialOnly(song)
            let quality = BeansAudioQuality.current
            BeansLogger.shared.log("▶ 开始播放：\(song.name) - \(song.artists)｜平台=\(song.source.rawValue) id=\(song.id) 音质=\(quality.level) 免费听歌=\(enableUnblock ? "开" : "关") 官方受限=\(strictUnlock ? "是" : "否")", level: .info)
            // 音乐源同步歌单中的直链歌曲：直接播放，无需走平台解析/解锁
            if let direct = song.directURL {
                let notice = self.thirdPartyVIPNotice(for: song, sourceTitle: song.directSourceName ?? "音乐源")
                await MainActor.run {
                    guard generation == self.loadGeneration else { return }
                    self.setupPlayer(url: direct, thirdPartyVIPNotice: notice)
                }
                return
            }
            if song.source == .kugou {
                urlString = try? await KugouMusicAPI.shared.songURL(song: song)
                if urlString == nil {
                    resolvedThirdParty = await kugouFallback(song: song, enableUnblock: enableUnblock)
                }
            } else if song.source == .qq, let mid = song.qqMid {
                // 是否有播放权益以 vkey 实际返回为准；会员接口识别失败时也必须尝试官方地址。
                urlString = try? await QQMusicAPI.shared.songURL(songmid: mid, mediaMid: song.qqMediaMid)
                if urlString == nil {
                    (urlString, resolvedThirdParty) = await qqFallback(song: song, quality: quality, enableUnblock: enableUnblock, strict: strictUnlock)
                }
            } else {
                (urlString, resolvedThirdParty) = await neteaseResolve(song: song, quality: quality, enableUnblock: enableUnblock, strict: strictUnlock)
            }
            if Task.isCancelled { return }
            if let resolved = resolvedThirdParty {
                let notice = self.thirdPartyVIPNotice(for: song, sourceTitle: resolved.sourceTitle)
                await MainActor.run {
                    guard generation == self.loadGeneration else { return }
                    self.setupPlayer(url: resolved.url, thirdPartyVIPNotice: notice)
                }
                return
            }
            guard let urlString, let url = URL(string: urlString) else {
                let thirdPartyAttempted = resolvedThirdParty != nil
                await MainActor.run {
                    guard generation == self.loadGeneration else { return }
                    self.isBuffering = false
                    self.loadFailed = true
                    if song.source != .kugou, self.shouldLockOfficialOnly(song) {
                        BeansLogger.shared.log("播放失败：\(song.name) - 未找到原唱音源（官方受限），拒绝翻唱版本", level: .error)
                        ToastCenter.shared.show("《\(song.name)》未找到原唱音源（官方受限），已停止播放，拒绝翻唱版本")
                    } else {
                        let hint = thirdPartyAttempted ? "（第三方音源尝试后无结果）" : "（第三方音源未命中）"
                        BeansLogger.shared.log("播放失败：\(song.name) - 无法解析播放地址\(hint)｜音质=\(quality.level) 免费听歌=\(enableUnblock ? "开" : "关")", level: .error)
                    }
                    // 解析失败后自动尝试跳过到下一首（避免卡在加载状态）
                    self.autoSkipIfNeeded()
                }
                return
            }
            if Task.isCancelled { return }
            await MainActor.run {
                guard generation == self.loadGeneration else { return }
                self.setupPlayer(url: url)
            }
        }
        currentLoadTask = task
    }

    /// 播放失败后自动跳过到下一首（仅在队列有多首歌时）
    private func autoSkipIfNeeded() {
        guard queue.count > 1 else { return }
        // 延迟 1.5 秒后自动跳过，给用户看到失败提示的时间
        // 若期间用户重试 / 手动切歌，loadFailed 会被重置，则不再跳过
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.loadFailed, self.isBuffering == false else { return }
            BeansLogger.shared.log("自动跳过失败歌曲：\(self.currentSong?.name ?? "未知")", level: .info)
            self.next(manual: false)
        }
    }

    /// 启动缓冲超时检测（30秒仍在缓冲则判定失败）
    private func startBufferingTimeout() {
        stopBufferingTimeout()
        let timer = Timer(timeInterval: 30, repeats: false) { [weak self] _ in
            guard let self, self.isBuffering else { return }
            BeansLogger.shared.log("缓冲超时：\(self.currentSong?.name ?? "未知")，尝试重试", level: .error)
            self.retryOrSkip()
        }
        RunLoop.main.add(timer, forMode: .common)
        bufferingTimeoutTimer = timer
    }

    private func stopBufferingTimeout() {
        bufferingTimeoutTimer?.invalidate()
        bufferingTimeoutTimer = nil
    }

    /// 重试当前歌曲，超过次数则跳过
    private func retryOrSkip() {
        if retryCountForCurrent < 2 {
            retryCountForCurrent += 1
            BeansLogger.shared.log("重试播放（第\(retryCountForCurrent)次）：\(currentSong?.name ?? "未知")", level: .info)
            loadCurrent()
        } else {
            loadFailed = true
            isBuffering = false
            Task { @MainActor in
                ToastCenter.shared.show("《\(currentSong?.name ?? "当前歌曲")》加载失败，自动跳过")
            }
            autoSkipIfNeeded()
        }
    }

    /// 延迟重试（item 加载失败时调用，避免与缓冲超时同时触发）

    // MARK: - 音效引擎切换
    
    /// 下载当前歌曲并切换到 AVAudioEngine 音效引擎播放
    private func switchToEffectEngine(url: URL) {
        effectDownloadTask?.cancel()
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("effect_\(UUID().uuidString).m4a")
        effectTempFile = tempFile
        
        let task = URLSession.shared.downloadTask(with: url) { [weak self] location, _, error in
            guard let self, let location = location, error == nil else { return }
            do {
                if FileManager.default.fileExists(atPath: tempFile.path) {
                    try? FileManager.default.removeItem(at: tempFile)
                }
                try FileManager.default.moveItem(at: location, to: tempFile)
                DispatchQueue.main.async {
                    self.startEffectEngine(file: tempFile)
                }
            } catch {
                BeansLogger.shared.log("音效下载失败: \(error)", level: .error)
            }
        }
        effectDownloadTask = task
        task.resume()
    }
    
    private func startEffectEngine(file: URL) {
        // 记录当前播放进度，切换音效后从该位置继续
        let currentPos: Double
        if let p = player {
            currentPos = CMTimeGetSeconds(p.currentTime())
        } else {
            currentPos = progress
        }
        player?.pause()
        EffectAudioEngine.shared.applyCurrentEffects()
        EffectAudioEngine.shared.onEnded = { [weak self] in
            DispatchQueue.main.async {
                self?.next(manual: false)
            }
        }
        EffectAudioEngine.shared.play(url: file, fromTime: currentPos, rate: Float(rate))
        usingEffectEngine = true
        isPlaying = true
        isBuffering = false
        // 同步进度
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self, self.usingEffectEngine else { timer.invalidate(); return }
            self.progress = EffectAudioEngine.shared.currentTime
            self.duration = EffectAudioEngine.shared.duration
            self.updateNowPlaying()
        }
    }
    
    /// 切回 AVPlayer 播放（关闭音效时）
    func switchToAVPlayer() {
        guard usingEffectEngine else { return }
        let currentTime = EffectAudioEngine.shared.currentTime
        EffectAudioEngine.shared.stop()
        usingEffectEngine = false
        if let player = player {
            player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
            player.playImmediately(atRate: Float(rate))
            isPlaying = true
        }
    }
    
    /// 音效设置变更时调用
    func effectsDidChange() {
        let fx = AudioFxStore.shared
        let effectsActive = fx.presetIndex != 0 || fx.bass > 0.01 || fx.reverbIndex > 0
        if effectsActive && !usingEffectEngine {
            // 启用音效：直接切换到音效引擎，从当前位置继续播放
            if let url = currentResolvedURL {
                switchToEffectEngine(url: url)
            } else if let song = currentSong {
                loadCurrent()
            }
        } else if !effectsActive && usingEffectEngine {
            // 关闭音效：切换回AVPlayer，从当前位置继续
            let pos = EffectAudioEngine.shared.currentTime
            switchToAVPlayer()
            if pos > 0.5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.seek(to: pos)
                }
            }
        } else if effectsActive && usingEffectEngine {
            // 已经在音效引擎中，实时更新效果参数（不重启播放）
            EffectAudioEngine.shared.applyCurrentEffects()
        }
    }

    private func retryOrSkipDelayed() {
        stopBufferingTimeout()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            if self.retryCountForCurrent < 2 {
                self.retryCountForCurrent += 1
                BeansLogger.shared.log("重试播放（第\(self.retryCountForCurrent)次）：\(self.currentSong?.name ?? "未知")", level: .info)
                self.loadCurrent()
            } else {
                self.loadFailed = true
                self.isBuffering = false
                Task { @MainActor in
                    ToastCenter.shared.show("《\(self.currentSong?.name ?? "当前歌曲")》加载失败，自动跳过")
                }
                self.autoSkipIfNeeded()
            }
        }
    }

    /// 网易云播放地址解析：按设置音质取 URL，VIP/灰色歌曲交给第三方解锁（借鉴 Kumone）
    private func neteaseResolve(song: Song, quality: BeansAudioQuality, enableUnblock: Bool, strict: Bool = false) async -> (String?, UnblockService.Resolved?) {
        var urlString: String?
        var resolved: UnblockService.Resolved?
        let infos = try? await NetEaseAPI.shared.songURLInfo(ids: [song.id], level: quality.level)
        var info = infos?[song.id]
        if (info?.url == nil || info?.freeTrial == true), quality != .standard {
            // 高音质拿不到时自动回落到标准音质
            let fallback = try? await NetEaseAPI.shared.songURLInfo(ids: [song.id], level: "standard")
            info = fallback?[song.id]
        }
        BeansLogger.shared.log("网易云解析：\(song.name) 音质=\(quality.level) 官方URL=\(info?.url == nil ? "无" : "有") 试听=\(info?.freeTrial == true ? "是" : "否")", level: .debug)
        // 试听片段 / 无 URL 一律不直接播放，交给第三方解锁，避免"只能试听"
        if let u = info?.url, info?.freeTrial != true {
            urlString = u
        }
        if urlString == nil, enableUnblock {
            resolved = await UnblockService.resolve(
                name: song.name,
                artists: song.artists,
                neteaseID: song.id,
                songSource: .netease,
                strict: strict
            )
        }
        BeansLogger.shared.log("网易云结果：\(song.name) 官方=\(urlString != nil ? "是" : "否") 第三方=\(resolved != nil ? "命中" : "未用/未命中")", level: .debug)
        return (urlString, resolved)
    }

    /// QQ 歌曲兜底：先在网易云按 歌名+歌手 匹配同名歌曲，免费完整 URL 直接播，VIP/无 URL 交给第三方解锁
    private func qqFallback(song: Song, quality: BeansAudioQuality, enableUnblock: Bool, strict: Bool = false) async -> (String?, UnblockService.Resolved?) {
        var urlString: String?
        var resolved: UnblockService.Resolved?
        if enableUnblock {
            resolved = await UnblockService.resolve(
                name: song.name,
                artists: song.artists,
                neteaseID: 0,
                songSource: .qq,
                qqMid: song.qqMid,
                strict: strict
            )
        }
        if resolved != nil { return (nil, resolved) }
        if let matched = await matchNetEaseSong(name: song.name, artists: song.artists, durationMS: Int(song.duration * 1000), strict: strict) {
            let infos = try? await NetEaseAPI.shared.songURLInfo(ids: [matched.id], level: quality.level)
            var info = infos?[matched.id]
            if (info?.url == nil || info?.freeTrial == true), quality != .standard {
                let fallback = try? await NetEaseAPI.shared.songURLInfo(ids: [matched.id], level: "standard")
                info = fallback?[matched.id]
            }
            // 免费完整 URL 直接用；试听片段 / 无 URL 交给第三方解锁
            if let u = info?.url, info?.freeTrial != true {
                urlString = u
            } else if enableUnblock {
                resolved = await UnblockService.resolve(
                    name: matched.name,
                    artists: matched.artists,
                    neteaseID: matched.id,
                    songSource: .netease,
                    strict: strict
                )
            }
        }
        BeansLogger.shared.log("QQ兜底：\(song.name) 官方=\(urlString != nil ? "是" : "否") 第三方=\(resolved != nil ? "命中" : "未用/未命中")", level: .debug)
        return (urlString, resolved)
    }

    /// 酷狗兜底：官方播放失败后使用内置音源作为备选。
    private func kugouFallback(song: Song, enableUnblock: Bool) async -> UnblockService.Resolved? {
        guard enableUnblock else { return nil }
        let kugouID = song.kugouHash ?? song.kugouAlbumAudioId ?? ""
        if kugouID.isEmpty {
            BeansLogger.shared.log("酷狗兜底跳过：缺少 album_audio_id/hash", level: .debug)
        } else {
            let resolved = await UnblockService.resolve(
                name: song.name,
                artists: song.artists,
                neteaseID: 0,
                songSource: .kugou,
                kugouID: kugouID
            )
            if let resolved {
                BeansLogger.shared.log("酷狗兜底：\(song.name) 酷狗音源=命中", level: .debug)
                return resolved
            }
        }

        let strict = shouldLockOfficialOnly(song)
        if let matched = await matchNetEaseSong(
            name: song.name,
            artists: song.artists,
            durationMS: Int(song.duration * 1000),
            strict: strict
        ) {
            let resolved = await UnblockService.resolve(
                name: matched.name,
                artists: matched.artists,
                neteaseID: matched.id,
                songSource: .netease,
                strict: strict
            )
            BeansLogger.shared.log("酷狗兜底转网易云音源：\(song.name) -> \(matched.name) 第三方=\(resolved != nil ? "命中" : "未命中")", level: .debug)
            return resolved
        }

        BeansLogger.shared.log("酷狗兜底：\(song.name) 第三方=未命中", level: .debug)
        return nil
    }

    /// 版权受限歌手名单：这些歌手的歌曲必须严格校验原唱（第三方搜索会误匹配翻唱，如周杰伦）
    /// 兼容第三方返回的英文歌手名（Jay Chou），统一按别名判断，避免漏判导致播放翻唱
    private func shouldLockOfficialOnly(_ song: Song) -> Bool {
        let artists = song.artists.lowercased()
        return artists.contains("周杰伦") || artists.contains("jay chou") || artists.contains("jaychou")
    }

    /// 在网易云按 歌名+歌手 匹配同名歌曲（QQ vkey 失败时的免费播放兜底）
    private func matchNetEaseSong(name: String, artists: String, durationMS: Int, strict: Bool = false) async -> Song? {
        let keyword = ([name, artists].filter { !$0.isEmpty }).joined(separator: " ")
        guard !keyword.isEmpty,
              let results = try? await NetEaseAPI.shared.search(keyword: keyword, limit: 8),
              !results.isEmpty else { return nil }
        let target = Double(durationMS) / 1000.0
        let artistTokens = artists.lowercased().split(whereSeparator: { $0 == " " || $0 == "/" || $0 == "&" }).map(String.init)
        // 优先：歌手匹配 + 时长接近（兼容 Jay Chou 别名）
        if let hit = results.first(where: { song in
            let durOK = abs(song.duration - target) < 12
            let songArtists = song.artists.lowercased()
            let artistOK = artistTokens.contains { !$0.isEmpty && songArtists.contains($0) }
                || (songArtists.contains("周杰伦") && artists.lowercased().contains("jay chou"))
            return durOK && artistOK
        }) { return hit }
        // 严格模式（周杰伦等版权歌手）：找不到原唱直接放弃，绝不返回翻唱
        if strict { return nil }
        // 其次：仅时长接近（必须足够接近才用，避免张冠李戴）
        if let hit = results.min(by: { abs($0.duration - target) < abs($1.duration - target) }),
           abs(hit.duration - target) < 20 {
            return hit
        }
        // 找不到可靠匹配：宁可播放失败，也不播放错误歌曲
        return nil
    }


    private func setupPlayer(url: URL, thirdPartyVIPNotice: ThirdPartyVIPNotice? = nil) {
        currentResolvedURL = url
        configureAudioSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        removeCurrentObservers()
        pendingThirdPartyVIPNotice = thirdPartyVIPNotice
        // QQ 官方 CDN（isure.stream.qqmusic.qq.com 等）要求 UA/Referer 请求头，
        // 否则裸 GET 会被拒绝（403），导致播放成功却无声、进度条不动。
        let item: AVPlayerItem
        if url.host?.contains("qq.com") == true {
            var headers = [
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:80.0) Gecko/20100101 Firefox/80.0",
                "Referer": "https://y.qq.com/",
            ]
            let cookie = QQMusicAuth.shared.cookieHeader
            if !cookie.isEmpty { headers["Cookie"] = cookie }
            let asset = AVURLAsset(url: url, options: [
                "AVURLAssetHTTPHeaderFieldsKey": headers
            ])
            item = AVPlayerItem(asset: asset)
        } else if url.host?.contains("kugou.com") == true || url.host?.contains("kgimg.com") == true {
            var headers = [
                "User-Agent": "Android15-1070-11440-46-0-DiscoveryDRADProtocol-wifi",
                "Referer": "https://www.kugou.com/",
            ]
            let cookie = KugouMusicAuth.shared.cookieHeader
            if !cookie.isEmpty { headers["Cookie"] = cookie }
            let asset = AVURLAsset(url: url, options: [
                "AVURLAssetHTTPHeaderFieldsKey": headers
            ])
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }
        let player = AVPlayer(playerItem: item)
        player.rate = Float(rate)
        self.player = player
        playbackConfirmed = false
        // 启动播放启动超时：30秒内未真正开始播放则判定失败
        startBufferingTimeout()
        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self, self.player === player, item.status == .failed else { return }
            self.loadFailed = true
            self.isBuffering = false
            self.isPlaying = false
            BeansLogger.shared.log("播放地址加载失败：\(item.error?.localizedDescription ?? "未知错误")", level: .error)
            // 加载失败：延迟自动重试（最多 2 次），仍失败则自动跳过
            self.retryOrSkipDelayed()
        }
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self, self.player === player else { return }
            if player.timeControlStatus == .playing {
                self.stopBufferingTimeout()
                self.retryCountForCurrent = 0
            }
            guard player.timeControlStatus == .playing, !self.playbackConfirmed else { return }
            self.playbackConfirmed = true
            if let song = self.currentSong {
                BeansLogger.shared.log("▶ 播放成功：\(song.name)｜域名=\(url.host ?? "?")", level: .info)
            }
            self.showPendingThirdPartyVIPNoticeIfNeeded()
        }
        player.volume = crossfadeEnabled ? 0 : 1.0
        player.playImmediately(atRate: Float(rate))
        isPlaying = true
        isBuffering = false
        loadFailed = false
        // 交叉淡入：新歌曲淡入
        if crossfadeEnabled {
            UIView.animate(withDuration: crossfadeDuration) {
                player.volume = 1.0
            }
        }
        // 记忆播放进度：长音频（>5分钟）自动恢复上次位置
        if let current = currentSong, current.duration > 300 {
            if let savedPosition = PlaybackProgressStore.shared.getProgress(songID: current.identityKey) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.seek(to: savedPosition)
                }
            }
        }
        // 修复：播放次数原先在 loadCurrent 里预计数，URL 加载失败/手动重试也会 +1，
        // 导致统计异常；改为真正开始播放时计数，且同一首歌同一会话只计一次。
        if let song = currentSong, lastCountedSongID != song.identityKey {
            bumpPlayCount(song)
            lastCountedSongID = song.identityKey
            // 听歌时长统计 + 等级经验
            ListeningStatsStore.shared.recordSongPlayed()
            // 如果启用了非默认音效，下载后切换到音效引擎
            if AudioFxStore.shared.presetIndex != 0 || AudioFxStore.shared.bass > 0.01 || AudioFxStore.shared.reverbIndex > 0 {
                self.switchToEffectEngine(url: url)
            }
            // 网易云听歌打卡（登录后同步时长，升级等级）
            if song.source == .netease, song.id > 0 {
                Task {
                    let dur = Int(self.duration > 0 ? self.duration : Double(song.duration))
                    await NetEaseAPI.shared.scrobble(songID: song.id, duration: dur)
                }
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self, let player = self.player else { return }
            if time.seconds.isFinite {
                if abs(time.seconds - self.lastPublishedProgress) >= 0.18 {
                    self.lastPublishedProgress = time.seconds
                    self.progress = time.seconds
                }
            }
            if let itemDuration = player.currentItem?.duration, itemDuration.isNumeric {
                let seconds = itemDuration.seconds
                if seconds.isFinite, abs(seconds - self.duration) > 0.25 {
                    self.duration = seconds
                }
            }
            let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            if waiting != self.isBuffering {
                self.isBuffering = waiting
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.playMode == .repeatOne {
                self.restartCurrent()
            } else {
                self.advance()
                self.loadCurrent()
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.loadFailed = true
            self?.isBuffering = false
            BeansLogger.shared.log("播放中断：AVPlayerItem 播放失败（解码或网络错误）", level: .error)
        }
        updateNowPlaying()
    }

    private func removeCurrentObservers() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
        }
        failureObserver = nil
        itemStatusObserver = nil
        timeControlStatusObserver = nil
        playbackConfirmed = false
        pendingThirdPartyVIPNotice = nil
        lastPublishedProgress = -1
        stopBufferingTimeout()
    }

    private func thirdPartyVIPNotice(for song: Song, sourceTitle: String) -> ThirdPartyVIPNotice? {
        guard song.isVIP else { return nil }
        guard defaults.object(forKey: thirdPartyVIPNoticeKey) as? Bool ?? true else { return nil }
        guard !hasMembership(for: song.source) else { return nil }
        let sourceName = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let src = sourceName.isEmpty ? "第三方音源" : sourceName
        return ThirdPartyVIPNotice(
            songKey: song.identityKey,
            message: "《\(song.name)》· \(src)"
        )
    }

    private func showPendingThirdPartyVIPNoticeIfNeeded() {
        guard let notice = pendingThirdPartyVIPNotice else { return }
        guard currentSong?.identityKey == notice.songKey else {
            pendingThirdPartyVIPNotice = nil
            return
        }
        guard defaults.object(forKey: thirdPartyVIPNoticeKey) as? Bool ?? true else {
            pendingThirdPartyVIPNotice = nil
            return
        }
        Task { @MainActor in
            ToastCenter.shared.show(notice.message)
        }
        BeansLogger.shared.log("第三方音源会员歌提醒：\(notice.message)", level: .info)
        pendingThirdPartyVIPNotice = nil
    }

    private func hasMembership(for source: SongSource) -> Bool {
        switch source {
        case .qq:
            return QQMusicAuth.shared.vipBadge != nil
        case .kugou:
            return KugouMusicAuth.shared.vipBadge != nil
        case .netease:
            guard let data = defaults.data(forKey: "beans.user"),
                  let user = try? JSONDecoder().decode(NetEaseUser.self, from: data) else {
                return false
            }
            return user.vipBadge != nil
        }
    }

    private func configureAudioSession() {
        if Self.applyAudioMixPreference(mixesWithOthers) {
            sessionConfigured = true
        } else {
            sessionConfigured = false
        }
    }

    @discardableResult
    static func applyAudioMixPreference(_ mixesWithOthers: Bool) -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            // 「与其他音频同时播放」开关：开启时 mixWithOthers，打开其他音频软件也能继续播放；关闭则自动暂停
            if mixesWithOthers {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            } else {
                try session.setCategory(.playback, mode: .default)
            }
            try session.setActive(true)
            return true
        } catch {
            BeansLogger.shared.log("音频会话配置失败：\(error.localizedDescription)", level: .error)
            return false
        }
    }

    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    /// 输出设备变化（插拔耳机 / 切换扬声器 / 来电路由等）后重新激活会话，避免播放无声
    @objc private func handleRouteChange(_ notification: Notification) {
        sessionConfigured = false
        configureAudioSession()
        if isPlaying, player?.timeControlStatus != .playing {
            player?.playImmediately(atRate: Float(rate))
        }
    }

    // MARK: - 来电/中断处理

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            // 开启「与其他音频同时播放」时，不被其他 App 音频中断，保持继续播放
            guard !mixesWithOthers else { return }
            player?.pause()
            isPlaying = false
        case .ended:
            // 中断结束后系统可能停用了音频会话，重新激活避免无声
            sessionConfigured = false
            configureAudioSession()
            if wasPlayingBeforeInterruption {
                player?.playImmediately(atRate: Float(rate))
                isPlaying = true
            }
        @unknown default:
            break
        }
    }

    // MARK: - 播放历史与统计

    private func pushHistory(_ song: Song) {
        history.removeAll { $0.identityKey == song.identityKey }
        history.insert(song, at: 0)
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: historyKey),
              let saved = try? JSONDecoder().decode([Song].self, from: data) else { return }
        history = saved
    }

    private func bumpPlayCount(_ song: Song) {
        playCounts[song.identityKey, default: 0] += 1
        if let data = try? JSONEncoder().encode(playCounts) {
            defaults.set(data, forKey: countsKey)
        }
    }

    private func loadPlayCounts() {
        guard let data = defaults.data(forKey: countsKey),
              let saved = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
        playCounts = saved
    }

    /// 听歌排行：按播放次数排序的前几首
    var topPlayed: [(song: Song, count: Int)] {
        var result: [(song: Song, count: Int)] = []
        for (key, count) in playCounts {
            if let song = history.first(where: { $0.identityKey == key }) {
                result.append((song, count))
            }
        }
        return result.sorted { $0.count > $1.count }.prefix(8).map { $0 }
    }

    // MARK: - 锁屏/控制中心

    private func updateNowPlaying() {
        guard let song = currentSong else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.artists,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: max(duration, song.duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0,
        ]
        if let artworkURL = song.coverURL {
            let artworkKey = song.identityKey + "|" + artworkURL.absoluteString
            if let cached = Self.nowPlayingArtworkCache.object(forKey: artworkURL as NSURL) {
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: cached.size) { _ in cached }
            } else if lastNowPlayingArtworkKey != artworkKey {
                lastNowPlayingArtworkKey = artworkKey
                Task {
                    if let data = try? Data(contentsOf: artworkURL), let image = UIImage(data: data) {
                        Self.nowPlayingArtworkCache.setObject(image, forKey: artworkURL as NSURL)
                        var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                    }
                }
            }
        } else {
            lastNowPlayingArtworkKey = nil
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.setupRemoteCommands() }
            return
        }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.player?.playImmediately(atRate: Float(self?.rate ?? 1.0))
            self?.isPlaying = true
            self?.updateNowPlaying()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.isPlaying = false
            self?.updateNowPlaying()
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }

    // MARK: - 与其他音频同时播放

    /// 与其他 App 音频混合播放。默认关闭，让系统把 Beans 作为主播放 App 显示到锁屏/灵动岛。
    var mixesWithOthers: Bool {
        get { defaults.object(forKey: audioMixKey) as? Bool ?? false }
        set {
            defaults.set(newValue, forKey: audioMixKey)
            sessionConfigured = false
            configureAudioSession()
        }
    }

}

// MARK: - Notification Names
extension Notification.Name {
    static let beansPlaybackStateDidChange = Notification.Name("beans.playback.state.didChange")
}
