import SwiftUI
import AVFoundation

// MARK: - 有声书数据模型
struct Audiobook: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let narrator: String
    let cover: String
    let intro: String
    let category: String
    let duration: String
    let source: String
}

struct AudiobookChapter: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let audioURL: String
    let duration: TimeInterval
}

// MARK: - 有声书播放器
class AudiobookPlayer: ObservableObject {
    static let shared = AudiobookPlayer()
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentChapter: AudiobookChapter?
    @Published var rate: Float = 1.0
    @Published var sleepTimerMinutes: Int = 0
    
    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func play(chapter: AudiobookChapter) {
        guard let url = URL(string: chapter.audioURL) else { return }
        currentChapter = chapter
        let item = AVPlayerItem(url: url)
        player?.replaceCurrentItem(with: item)
        if player == nil {
            player = AVPlayer(playerItem: item)
        }
        player?.play()
        player?.rate = rate
        isPlaying = true
        duration = chapter.duration
        setupTimeObserver()
    }
    
    private func setupTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
    
    func togglePlay() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            player?.rate = rate
            isPlaying = true
        }
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
    }
    
    func forward(seconds: TimeInterval = 15) {
        seek(to: min(currentTime + seconds, duration))
    }
    
    func backward(seconds: TimeInterval = 15) {
        seek(to: max(currentTime - seconds, 0))
    }
    
    func setRate(_ r: Float) {
        rate = r
        player?.rate = isPlaying ? r : 0
    }
    
    func stop() {
        player?.pause()
        isPlaying = false
        currentTime = 0
    }
}

// MARK: - 有声书主界面
struct AudiobookModuleView: View {
    @State private var searchText = ""
        @State private var books: [Audiobook] = Audiobook.sampleData
    @StateObject private var player = AudiobookPlayer.shared
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索有声书、主播", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(["全部","小说","历史","悬疑","儿童","知识","相声","评书"], id: \.self) { cat in
                                Text(cat)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(theme.accent.highlight.opacity(0.15))
                                    .foregroundColor(theme.accent.highlight)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 10)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredBooks) { book in
                                NavigationLink(value: book) {
                                    AudiobookRow(book: book)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
                
                // 迷你播放器
                if player.currentChapter != nil {
                    VStack {
                        Spacer()
                        MiniAudiobookPlayer()
                    }
                }
            }
            .navigationTitle("有声书")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Audiobook.self) { book in
                AudiobookDetailView(book: book)
            }
        }
    }
    
    var filteredBooks: [Audiobook] {
        if searchText.isEmpty { return books }
        return books.filter { $0.title.contains(searchText) || $0.author.contains(searchText) || $0.narrator.contains(searchText) }
    }
}

struct AudiobookRow: View {
    let book: Audiobook
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        HStack(spacing: 14) {
                AsyncImage(url: URL(string: book.cover)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(theme.accent.highlight.opacity(0.2))
                        .overlay(Image(systemName: "headphones").foregroundColor(theme.accent.highlight))
                }
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(book.author + " · " + book.narrator)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Tag(text: book.category)
                        Text(book.duration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 有声书详情
struct AudiobookDetailView: View {
    let book: Audiobook
    @State private var chapters: [AudiobookChapter] = AudiobookChapter.sampleData
    @StateObject private var player = AudiobookPlayer.shared
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: URL(string: book.cover)) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(theme.accent.highlight.opacity(0.2))
                    }
                    .frame(width: 110, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title)
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        Text("作者：" + book.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("主播：" + book.narrator)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Tag(text: book.category)
                            Text(book.duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(book.source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Text(book.intro)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .padding(.horizontal)
                
                Button {
                    if let first = chapters.first {
                        player.play(chapter: first)
                    }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始播放")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.accent.highlight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                Text("章节列表")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                
                ForEach(chapters) { chapter in
                    Button {
                        player.play(chapter: chapter)
                    } label: {
                        HStack {
                            Image(systemName: player.currentChapter?.id == chapter.id && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .foregroundColor(theme.accent.highlight)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter.title)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text(formatDuration(chapter.duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top)
            .padding(.bottom, 100)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if player.currentChapter != nil {
                MiniAudiobookPlayer()
            }
        }
    }
    
    private func formatDuration(_ d: TimeInterval) -> String {
        let m = Int(d) / 60
        let s = Int(d) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - 迷你播放器
struct MiniAudiobookPlayer: View {
    @StateObject private var player = AudiobookPlayer.shared
    @State private var showFullPlayer = false
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: player.duration > 0 ? player.currentTime / player.duration : 0)
                .tint(theme.accent.highlight)
            
            HStack(spacing: 12) {
                Image(systemName: "headphones.circle.fill")
                    .font(.title2)
                    .foregroundColor(theme.accent.highlight)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentChapter?.title ?? "未播放")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(formatTime(player.currentTime) + " / " + formatTime(player.duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button { player.backward() } label: {
                    Image(systemName: "gobackward.15")
                        .foregroundColor(.primary)
                }
                
                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(theme.accent.highlight)
                        .frame(width: 40, height: 40)
                }
                
                Button { player.forward() } label: {
                    Image(systemName: "goforward.15")
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .onTapGesture { showFullPlayer = true }
        .sheet(isPresented: $showFullPlayer) { FullAudiobookPlayer() }
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - 全屏播放器
struct FullAudiobookPlayer: View {
    @StateObject private var player = AudiobookPlayer.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // 封面
                    RoundedRectangle(cornerRadius: 20)
                        .fill(theme.accent.highlight.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Image(systemName: "headphones")
                                .font(.system(size: 60))
                                .foregroundColor(theme.accent.highlight)
                        )
                        .shadow(radius: 20)
                    
                    Text(player.currentChapter?.title ?? "未播放")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    // 进度条
                    VStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ), in: 0...max(player.duration, 1))
                        .tint(theme.accent.highlight)
                        
                        HStack {
                            Text(formatTime(player.currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatTime(player.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // 控制按钮
                    HStack(spacing: 40) {
                        Button { player.backward(seconds: 30) } label: {
                            Image(systemName: "gobackward.30")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        
                        Button { player.backward() } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title)
                                .foregroundColor(.primary)
                        }
                        
                        Button {
                            player.togglePlay()
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(theme.accent.highlight)
                        }
                        
                        Button { player.forward() } label: {
                            Image(systemName: "goforward.15")
                                .font(.title)
                                .foregroundColor(.primary)
                        }
                        
                        Button { player.forward(seconds: 30) } label: {
                            Image(systemName: "goforward.30")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // 倍速
                    HStack(spacing: 12) {
                        ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                            Button {
                                player.setRate(Float(r))
                            } label: {
                                Text("\(r, specifier: "%.2f")x")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(player.rate == Float(r) ? theme.accent.highlight : Color.gray.opacity(0.2))
                                    .foregroundColor(player.rate == Float(r) ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    // 睡眠定时
                    HStack {
                        Image(systemName: "moon.zzz")
                            .foregroundColor(.primary)
                        Text("睡眠定时")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Picker("定时", selection: $player.sleepTimerMinutes) {
                            Text("关闭").tag(0)
                            Text("15分钟").tag(15)
                            Text("30分钟").tag(30)
                            Text("60分钟").tag(60)
                            Text("90分钟").tag(90)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle("正在播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - 样例数据
extension Audiobook {
    static let sampleData: [Audiobook] = [
        Audiobook(id: "1", title: "三体", author: "刘慈欣", narrator: "王明军", cover: "https://picsum.photos/seed/audio1/200/280", intro: "文化大革命如火如荼进行的同时，军方探寻外星文明的绝秘计划红岸工程取得了突破性进展。但在按下发射键的那一刻，历经劫难的叶文洁没有意识到，她彻底改变了人类的命运。", category: "科幻", duration: "23小时", source: "有声源1"),
        Audiobook(id: "2", title: "明朝那些事儿", author: "当年明月", narrator: "王更新", cover: "https://picsum.photos/seed/audio2/200/280", intro: "《明朝那些事儿》主要讲述的是从1344年到1644年这三百年间关于明朝的一些故事。以史料为基础，以年代和具体人物为主线，并加入了小说的笔法。", category: "历史", duration: "56小时", source: "有声源2"),
        Audiobook(id: "3", title: "鬼吹灯", author: "天下霸唱", narrator: "周建龙", cover: "https://picsum.photos/seed/audio3/200/280", intro: "胡八一上山下乡来到东北地区，在一个叫做岗岗营子的村庄插队时，因为一次偶然的机会，和自己的好友王胖子一起加入了一支考古队。", category: "悬疑", duration: "45小时", source: "有声源1"),
        Audiobook(id: "4", title: "小王子", author: "圣埃克苏佩里", narrator: "董乐", cover: "https://picsum.photos/seed/audio4/200/280", intro: "以一位飞行员作为故事叙述者，讲述了小王子从自己星球出发前往地球的过程中，所经历的各种历险。", category: "儿童", duration: "1小时", source: "有声源3"),
        Audiobook(id: "5", title: "郭德纲相声精选", author: "郭德纲", narrator: "郭德纲", cover: "https://picsum.photos/seed/audio5/200/280", intro: "郭德纲经典相声合集，包括《我这一辈子》《西征梦》《论五十年相声之现状》等经典作品。", category: "相声", duration: "30小时", source: "有声源1"),
        Audiobook(id: "6", title: "人类简史", author: "尤瓦尔·赫拉利", narrator: "林宏", cover: "https://picsum.photos/seed/audio6/200/280", intro: "从十万年前有生命迹象开始到21世纪资本、科技交织的人类发展史。理清影响人类发展的重大脉络，挖掘人类文化、宗教、法律、国家、信贷等产生的根源。", category: "知识", duration: "18小时", source: "有声源2"),
    ]
}

extension AudiobookChapter {
    static let sampleData: [AudiobookChapter] = [
        AudiobookChapter(id: "1", title: "第一章 科学边界", audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3", duration: 1800),
        AudiobookChapter(id: "2", title: "第二章 台球", audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3", duration: 1650),
        AudiobookChapter(id: "3", title: "第三章 射手和农场主", audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3", duration: 1720),
        AudiobookChapter(id: "4", title: "第四章 三体问题", audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3", duration: 1900),
        AudiobookChapter(id: "5", title: "第五章 叶文洁", audioURL: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3", duration: 1580),
    ]
}
