import SwiftUI

// MARK: - 漫画数据模型
struct Comic: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let cover: String
    let intro: String
    let category: String
    let status: String
    let source: String
}

struct ComicChapter: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let imageURLs: [String]
}

// MARK: - 漫画设置
class ComicSettings: ObservableObject {
    static let shared = ComicSettings()
    @AppStorage("comic_reading_direction") var readingDirection: Int = 0 // 0=从左到右 1=从右到左 2=条漫
    @AppStorage("comic_background") var bgColorIndex: Int = 0
    @AppStorage("comic_preload") var preloadCount: Int = 2
    
    let bgColors: [Color] = [.black, .white, .gray]
}

// MARK: - 漫画主界面
struct ComicModuleView: View {
    @StateObject private var settings = ComicSettings.shared
    @State private var searchText = ""
        @State private var showSettings = false
    @State private var showSources = false
    @State private var comics: [Comic] = Comic.sampleData
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索漫画、作者", text: $searchText)
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
                            ForEach(["全部","热血","恋爱","校园","科幻","悬疑","搞笑","玄幻","治愈"], id: \.self) { cat in
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
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 16) {
                            ForEach(filteredComics) { comic in
                                NavigationLink(value: comic) {
                                    ComicCoverCell(comic: comic)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("漫画")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showSources = true } label: { Label("音源管理", systemImage: "antenna.radiowaves.left.and.right") }
                        Button { showSettings = true } label: { Label("阅读设置", systemImage: "gearshape") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { ComicSettingsView() }
            .sheet(isPresented: $showSources) { ComicSourcesView() }
            .navigationDestination(for: Comic.self) { comic in
                ComicDetailView(comic: comic)
            }
        }
    }
    
    var filteredComics: [Comic] {
        if searchText.isEmpty { return comics }
        return comics.filter { $0.title.contains(searchText) || $0.author.contains(searchText) }
    }
}

struct ComicCoverCell: View {
    let comic: Comic
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        VStack(spacing: 6) {
                AsyncImage(url: URL(string: comic.cover)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(theme.accent.highlight.opacity(0.2))
                        .overlay(Image(systemName: "photo").foregroundColor(theme.accent.highlight))
                }
                .frame(width: 100, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
                
                Text(comic.title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
            }
    }
}

// MARK: - 漫画详情
struct ComicDetailView: View {
    let comic: Comic
    @State private var chapters: [ComicChapter] = ComicChapter.sampleData
        @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: URL(string: comic.cover)) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(theme.accent.highlight.opacity(0.2))
                    }
                    .frame(width: 100, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comic.title)
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        Text(comic.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Tag(text: comic.category)
                            Tag(text: comic.status)
                        }
                        Text(comic.source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Text(comic.intro)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .padding(.horizontal)
                
                NavigationLink {
                    if let first = chapters.first {
                        ComicReaderView(chapter: first)
                    }
                } label: {
                    Text("开始阅读")
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
                    NavigationLink(value: chapter) {
                        HStack {
                            Text(chapter.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
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
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(comic.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ComicChapter.self) { chapter in
                ComicReaderView(chapter: chapter)
            }
    }
}

// MARK: - 漫画阅读器
struct ComicReaderView: View {
    let chapter: ComicChapter
    @StateObject private var settings = ComicSettings.shared
    @State private var currentPage = 0
    @State private var showControls = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                settings.bgColors[settings.bgColorIndex].ignoresSafeArea()
                
                if settings.readingDirection == 2 {
                    // 条漫模式 - 垂直滚动
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(0..<chapter.imageURLs.count, id: \.self) { idx in
                                AsyncImage(url: URL(string: chapter.imageURLs[idx])) { img in
                                    img.resizable().aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Rectangle().fill(Color.gray.opacity(0.2))
                                        .frame(height: 300)
                                        .overlay(ProgressView())
                                }
                                .frame(width: geo.size.width)
                            }
                        }
                    }
                    .onTapGesture { withAnimation { showControls.toggle() } }
                } else {
                    // 翻页模式
                    TabView(selection: $currentPage) {
                        ForEach(0..<chapter.imageURLs.count, id: \.self) { idx in
                            AsyncImage(url: URL(string: chapter.imageURLs[idx])) { img in
                                img.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.2))
                                    .overlay(ProgressView())
                            }
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .environment(\.layoutDirection, settings.readingDirection == 1 ? .rightToLeft : .leftToRight)
                    .onTapGesture { withAnimation { showControls.toggle() } }
                }
                
                if showControls {
                    VStack {
                        HStack {
                            Text(chapter.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(currentPage + 1)/\(chapter.imageURLs.count)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        
                        Spacer()
                        
                        HStack(spacing: 30) {
                            Button {
                                settings.readingDirection = (settings.readingDirection + 1) % 3
                            } label: {
                                VStack {
                                    Image(systemName: ["arrow.left.to.line","arrow.right.to.line","arrow.down.to.line"][settings.readingDirection])
                                    Text(["左到右","右到左","条漫"][settings.readingDirection])
                                }
                            }
                            Button {
                                settings.bgColorIndex = (settings.bgColorIndex + 1) % settings.bgColors.count
                            } label: {
                                VStack {
                                    Image(systemName: "circle.lefthalf.filled")
                                    Text("背景")
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                    }
                    .transition(.opacity)
                }
            }
        }
        .navigationBarHidden(showControls)
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 漫画设置
struct ComicSettingsView: View {
    @StateObject private var settings = ComicSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("阅读方向") {
                    Picker("方向", selection: $settings.readingDirection) {
                        Text("从左到右").tag(0)
                        Text("从右到左（日漫）").tag(1)
                        Text("条漫（上下滚动）").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("背景颜色") {
                    Picker("背景", selection: $settings.bgColorIndex) {
                        Text("黑色").tag(0)
                        Text("白色").tag(1)
                        Text("灰色").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("预加载") {
                    Stepper("预加载 \(settings.preloadCount) 页", value: $settings.preloadCount, in: 1...5)
                }
            }
            .navigationTitle("漫画设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 样例数据
extension Comic {
    static let sampleData: [Comic] = [
        Comic(id: "1", title: "海贼王", author: "尾田荣一郎", cover: "https://picsum.photos/seed/comic1/200/280", intro: "拥有财富、名声、权力，这世界上的一切的男人海贼王哥尔·D·罗杰，在被行刑受死之前说了一句话，让全世界的人都涌向了大海。", category: "热血", status: "连载中", source: "漫画源1"),
        Comic(id: "2", title: "进击的巨人", author: "谏山创", cover: "https://picsum.photos/seed/comic2/200/280", intro: "那一天，人类终于回想起了，曾经一度被它们所支配的恐怖，还有被囚禁于鸟笼中的那份屈辱。", category: "科幻", status: "完结", source: "漫画源2"),
        Comic(id: "3", title: "鬼灭之刃", author: "吾峠呼世晴", cover: "https://picsum.photos/seed/comic3/200/280", intro: "大正时期，日本。卖炭的心地善良的少年炭治郎，有一天因卖炭而离开家，回到家时发现家人被鬼杀死了。", category: "热血", status: "完结", source: "漫画源1"),
        Comic(id: "4", title: "咒术回战", author: "芥见下下", cover: "https://picsum.photos/seed/comic4/200/280", intro: "高中生虎杖悠仁为了解救被诅咒袭击的学长学姐，吞下了诅咒之王两面宿傩的手指，从此与宿傩共用一个身体。", category: "玄幻", status: "连载中", source: "漫画源3"),
        Comic(id: "5", title: "间谍过家家", author: "远藤达哉", cover: "https://picsum.photos/seed/comic5/200/280", intro: "为了潜入名校，西国能力最强的间谍黄昏被下令组建家庭。但是，他的女儿是能够读心的超能力者，妻子是杀手！", category: "搞笑", status: "连载中", source: "漫画源2"),
        Comic(id: "6", title: "葬送的芙莉莲", author: "山田钟人", cover: "https://picsum.photos/seed/comic6/200/280", intro: "魔王被勇者一行打倒后，精灵魔法使芙莉莲与勇者们分别。千年的时光对于长寿的精灵来说不过是转瞬即逝。", category: "治愈", status: "连载中", source: "漫画源1"),
    ]
}

extension ComicChapter {
    static let sampleData: [ComicChapter] = [
        ComicChapter(id: "1", title: "第1话", imageURLs: (1...8).map { "https://picsum.photos/seed/comic_page_1_\($0)/800/1200" }),
        ComicChapter(id: "2", title: "第2话", imageURLs: (1...8).map { "https://picsum.photos/seed/comic_page_2_\($0)/800/1200" }),
        ComicChapter(id: "3", title: "第3话", imageURLs: (1...8).map { "https://picsum.photos/seed/comic_page_3_\($0)/800/1200" }),
    ]
}

// MARK: - 漫画音源管理
struct ComicSourcesView: View {
    @StateObject private var store = ComicSourceStore.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach($store.sources) { $source in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name)
                                .font(.headline)
                            Text(source.baseURL)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $source.enabled)
                    }
                }
            }
            .navigationTitle("漫画音源（\(store.sources.filter{$0.enabled}.count)个启用）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
