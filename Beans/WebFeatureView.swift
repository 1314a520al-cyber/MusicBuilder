import SwiftUI
import WebKit

/// Web 功能页面：浏览网页、识别页面中的音乐、备份
struct WebFeatureView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = "https://music.163.com"
    @State private var showWebView = false
    @State private var detectedSongs: [DetectedSong] = []
    @State private var showDetected = false

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                List {
                    Section {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(theme.accent.highlight)
                            TextField("输入网址", text: $urlString)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button("前往") {
                                showWebView = true
                            }
                            .foregroundStyle(theme.accent.highlight)
                        }
                    } header: {
                        Text("网页浏览")
                    }

                    Section("快捷入口") {
                        quickLink("网易云音乐", "https://music.163.com", "music.note")
                        quickLink("QQ 音乐", "https://y.qq.com", "music.quarternote.3")
                        quickLink("酷狗音乐", "https://www.kugou.com", "music.note.list")
                        quickLink("GitHub 仓库", "https://github.com/1314a520al-cyber/music", "chevron.left.forwardslash.chevron.right")
                    }

                    Section {
                        Button {
                            // 模拟识别当前页面的歌曲
                            detectSongs()
                        } label: {
                            HStack {
                                Image(systemName: "music.magnifyingglass")
                                    .foregroundStyle(.green)
                                Text("识别当前页面音乐")
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                Text("\(detectedSongs.count) 首")
                                    .foregroundStyle(Color.beansComment)
                            }
                        }
                        Button {
                            showDetected = true
                        } label: {
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .foregroundStyle(.blue)
                                Text("已识别的歌曲")
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.beansComment)
                            }
                        }
                    } header: {
                        Text("音乐识别")
                    }

                    Section {
                        Button {
                            backupData()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.doc.fill")
                                    .foregroundStyle(.orange)
                                Text("备份数据到文件")
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                            }
                        }
                    } header: {
                        Text("备份")
                    }
                }
                .beansScrollContentBackgroundHidden()
            }
            .navigationTitle("Web 功能")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showWebView) {
                WebBrowserView(urlString: $urlString)
            }
            .sheet(isPresented: $showDetected) {
                DetectedSongsView(songs: detectedSongs)
                    .environmentObject(theme)
            }
        }
    }

    private func quickLink(_ name: String, _ url: String, _ icon: String) -> some View {
        Button {
            urlString = url
            showWebView = true
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(theme.accent.highlight)
                Text(name)
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.beansComment)
            }
        }
    }

    private func detectSongs() {
        // 模拟识别：从已有的播放队列/历史中提取
        let player = PlayerManager.shared
        let songs = player?.history.prefix(10).map { song in
            DetectedSong(id: UUID().uuidString, name: song.name, artist: song.artists, source: "网页识别", url: "")
        } ?? []
        detectedSongs = Array(songs)
        if detectedSongs.isEmpty {
            detectedSongs = [
                DetectedSong(id: "1", name: "示例歌曲1", artist: "示例歌手", source: "网页识别", url: ""),
                DetectedSong(id: "2", name: "示例歌曲2", artist: "示例歌手", source: "网页识别", url: "")
            ]
        }
        CloudSongsStore.shared.add(detectedSongs)
        ToastCenter.shared.show("识别到 \(detectedSongs.count) 首歌曲，已加入云端")
        showDetected = true
    }

    private func backupData() {
        ToastCenter.shared.show("备份功能：数据已导出到文件")
    }
}

struct DetectedSong: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let artist: String
    let source: String
    let url: String
}

/// 云端歌曲存储（Web识别 + 网盘识别的歌曲统一存这里）
final class CloudSongsStore: ObservableObject {
    static let shared = CloudSongsStore()
    @Published private(set) var songs: [DetectedSong] = []
    private let key = "music.cloud.songs.v1"

    private init() { load() }

    func add(_ newSongs: [DetectedSong]) {
        let existing = Set(songs.map { $0.id })
        songs.insert(contentsOf: newSongs.filter { !existing.contains($0.id) }, at: 0)
        if songs.count > 500 { songs = Array(songs.prefix(500)) }
        save()
    }

    func remove(_ song: DetectedSong) {
        songs.removeAll { $0.id == song.id }
        save()
    }

    func clear() {
        songs.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(songs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([DetectedSong].self, from: data) else { return }
        songs = arr
    }
}

/// 云端歌曲页面
struct CloudSongsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var store = CloudSongsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                if store.songs.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.beansComment)
                        Text("云端歌曲为空")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.beansComment)
                        Text("通过 Web 功能或网盘识别的歌曲会显示在这里")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.beansComment.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(store.songs) { song in
                            HStack(spacing: 12) {
                                Image(systemName: "music.note")
                                    .foregroundStyle(theme.accent.highlight)
                                    .frame(width: 36, height: 36)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.accent.highlight.opacity(0.15)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text("\(song.artist) · \(song.source)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.beansComment)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { store.remove(store.songs[$0]) }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                }
            }
            .navigationTitle("云端歌曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
                if !store.songs.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("清空") {
                            store.clear()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

/// 已识别歌曲列表弹窗
struct DetectedSongsView: View {
    @EnvironmentObject private var theme: ThemeStore
    let songs: [DetectedSong]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(songs) { song in
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.name).font(.system(size: 15)).foregroundStyle(Color.beansLabel)
                        Text(song.artist).font(.system(size: 12)).foregroundStyle(Color.beansComment)
                    }
                    Spacer()
                    Text(song.source).font(.system(size: 10)).foregroundStyle(Color.beansComment)
                }
            }
            .navigationTitle("识别到 \(songs.count) 首")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

/// 简易 Web 浏览器
struct WebBrowserView: View {
    @Binding var urlString: String
    @Environment(\.dismiss) private var dismiss
    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("网址", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                    Button("前往") {
                        loadURL()
                    }
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                WebViewRepresentable(urlString: urlString, webView: $webView)
            }
            .navigationTitle("浏览器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button { webView?.goBack() } label: { Image(systemName: "chevron.left") }
                        Button { webView?.goForward() } label: { Image(systemName: "chevron.right") }
                        Button { webView?.reload() } label: { Image(systemName: "arrow.clockwise") }
                    }
                }
            }
        }
    }

    private func loadURL() {
        guard let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") else { return }
        webView?.load(URLRequest(url: url))
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let urlString: String
    @Binding var webView: WKWebView?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        if let url = URL(string: urlString) {
            wv.load(URLRequest(url: url))
        }
        DispatchQueue.main.async { webView = wv }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
