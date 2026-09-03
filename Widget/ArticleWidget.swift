import WidgetKit
import SwiftUI

// MARK: - 共享数据（通过 App Group）
struct SharedNowPlaying: Codable {
    let songName: String
    let artist: String
    let coverURL: String
    let isPlaying: Bool
    let timestamp: TimeInterval
}

enum SharedStore {
    static let groupID = "group.com.article.app"
    static let nowPlayingKey = "music.nowPlaying"
    static let recommendationsKey = "music.recommendations"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    static func nowPlaying() -> SharedNowPlaying? {
        guard let data = defaults?.data(forKey: nowPlayingKey) else { return nil }
        return try? JSONDecoder().decode(SharedNowPlaying.self, from: data)
    }

    static func recommendations() -> [String] {
        defaults?.stringArray(forKey: recommendationsKey) ?? ["每日推荐", "私人FM", "排行榜"]
    }
}

// MARK: - Widget 数据模型
struct MusicEntry: TimelineEntry {
    let date: Date
    let song: SharedNowPlaying?
    let recommendations: [String]
}

// MARK: - Timeline Provider
struct MusicProvider: TimelineProvider {
    func placeholder(in context: Context) -> MusicEntry {
        MusicEntry(date: Date(), song: nil, recommendations: SharedStore.recommendations())
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> Void) {
        let entry = MusicEntry(date: Date(), song: SharedStore.nowPlaying(), recommendations: SharedStore.recommendations())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicEntry>) -> Void) {
        let entry = MusicEntry(date: Date(), song: SharedStore.nowPlaying(), recommendations: SharedStore.recommendations())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }
}

// MARK: - 小组件视图
struct ArticleWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MusicProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// 小号：当前播放歌曲封面 + 歌名
struct SmallWidgetView: View {
    var entry: MusicEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.20), Color(red: 0.06, green: 0.05, blue: 0.12)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
            // 装饰光晕
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 80, height: 80)
                .blur(radius: 20)
                .offset(x: 20, y: -20)
            VStack(spacing: 6) {
                if let song = entry.song {
                    ZStack {
                        if let url = URL(string: song.coverURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                case .failure: ZStack { RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.1)); Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5)) }
                                case .empty: ProgressView().scaleEffect(0.7)
                                @unknown default: Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    Text(song.songName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    if song.isPlaying {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { i in
                                Capsule()
                                    .fill(Color.green.opacity(0.8))
                                    .frame(width: 2, height: CGFloat(4 + i * 3))
                            }
                        }
                        .frame(height: 8)
                    } else {
                        Text("已暂停")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Music")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("发现好音乐")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(10)
        }
    }
}

// 中号：当前播放 + 快捷推荐
struct MediumWidgetView: View {
    var entry: MusicEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.10, blue: 0.20), Color(red: 0.06, green: 0.05, blue: 0.12)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(spacing: 14) {
                if let song = entry.song {
                    VStack(spacing: 4) {
                        if let url = URL(string: song.coverURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default: Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Text(song.isPlaying ? "播放中" : "已暂停")
                            .font(.system(size: 9))
                            .foregroundStyle(song.isPlaying ? .green : .white.opacity(0.5))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.songName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(entry.recommendations.prefix(3), id: \.self) { rec in
                                Text(rec)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Capsule().fill(.white.opacity(0.12)))
                            }
                        }
                    }
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Music")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("发现好音乐")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(entry.recommendations.prefix(3), id: \.self) { rec in
                                Text(rec)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(.white.opacity(0.12)))
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(14)
        }
    }
}

// 大号：当前播放 + 推荐列表
struct LargeWidgetView: View {
    var entry: MusicEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.15, green: 0.15, blue: 0.2), Color(red: 0.1, green: 0.1, blue: 0.15)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if let song = entry.song {
                        if let url = URL(string: song.coverURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img): img.resizable().scaledToFill()
                                default: Image(systemName: "music.note").foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.songName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Circle().fill(song.isPlaying ? Color.green : Color.gray.opacity(0.5)).frame(width: 6, height: 6)
                                Text(song.isPlaying ? "正在播放" : "已暂停")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Music")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                Divider().background(.white.opacity(0.1))
                Text("为你推荐")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.recommendations.prefix(5), id: \.self) { rec in
                        HStack(spacing: 10) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(rec)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                        }
                    }
                }
                Spacer()
            }
            .padding(16)
        }
    }
}

// MARK: - Widget 配置
struct ArticleWidget: Widget {
    let kind: String = "ArticleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicProvider()) { entry in
            ArticleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Music")
        .description("查看当前播放歌曲和推荐歌单，点击快速打开音乐。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct ArticleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ArticleWidget()
    }
}
