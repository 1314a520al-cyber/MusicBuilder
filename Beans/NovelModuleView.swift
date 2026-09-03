import SwiftUI

// MARK: - 小说数据模型
struct Novel: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let cover: String
    let intro: String
    let category: String
    let status: String
    let wordCount: String
    let source: String
}

struct NovelChapter: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let content: String
}

// MARK: - 小说数据源
class NovelSourceStore: ObservableObject {
    static let shared = NovelSourceStore()
    @Published var sources: [NovelSource] = [
        NovelSource(id: "biquge", name: "笔趣阁", baseURL: "https://www.biquge.co", enabled: true),
        NovelSource(id: "qidian", name: "起点镜像", baseURL: "https://www.qidian.com", enabled: true),
        NovelSource(id: "zongheng", name: "纵横中文", baseURL: "https://www.zongheng.com", enabled: true),
        NovelSource(id: "jjwxc", name: "晋江文学", baseURL: "https://www.jjwxc.net", enabled: true),
        NovelSource(id: "fanqie", name: "番茄小说", baseURL: "https://fanqienovel.com", enabled: true),
        NovelSource(id: "biquge2", name: "笔趣阁2", baseURL: "https://www.biquwx.la", enabled: false),
        NovelSource(id: "xbiquge", name: "新笔趣阁", baseURL: "https://www.xbiquge.so", enabled: true),
        NovelSource(id: "shuquge", name: "书趣阁", baseURL: "https://www.shuquge.com", enabled: false),
        NovelSource(id: "17k", name: "17K小说", baseURL: "https://www.17k.com", enabled: true),
        NovelSource(id: "chuangshi", name: "创世中文", baseURL: "https://chuangshi.qq.com", enabled: true),
        NovelSource(id: "zhulang", name: "逐浪小说", baseURL: "https://www.zhulang.com", enabled: true),
        NovelSource(id: "hongxiu", name: "红袖添香", baseURL: "https://www.hongxiu.com", enabled: true),
        NovelSource(id: "xiaoxiang", name: "潇湘书院", baseURL: "https://www.xxsy.net", enabled: true),
        NovelSource(id: "readnovel", name: "小说阅读网", baseURL: "https://www.readnovel.com", enabled: false),
        NovelSource(id: "faloo", name: "飞卢小说", baseURL: "https://b.faloo.com", enabled: true),
        NovelSource(id: "ciweimao", name: "刺猬猫", baseURL: "https://www.ciweimao.com", enabled: true),
        NovelSource(id: "sfacg", name: "SF轻小说", baseURL: "https://book.sfacg.com", enabled: true),
        NovelSource(id: "guidaye", name: "鬼大爷", baseURL: "https://www.guidaye.com", enabled: false),
        NovelSource(id: "ibiquge", name: "笔趣阁i", baseURL: "https://www.ibiquge.info", enabled: true),
        NovelSource(id: "xbiquge", name: "xbiquge", baseURL: "https://www.xbiquge.la", enabled: true),
        NovelSource(id: "uuks", name: "UU看书", baseURL: "https://www.uuks.org", enabled: false),
        NovelSource(id: "99csw", name: "九九藏书", baseURL: "https://www.99csw.com", enabled: true),
        NovelSource(id: "dingdian", name: "顶点小说", baseURL: "https://www.23wx.la", enabled: true),
        NovelSource(id: "69shu", name: "69书吧", baseURL: "https://www.69shu.com", enabled: true),
        NovelSource(id: "lewen", name: "乐文小说", baseURL: "https://www.lewen8.com", enabled: true),
        NovelSource(id: "qianqian", name: "千千看书", baseURL: "https://www.qqxs.la", enabled: true),
        NovelSource(id: "yanqing", name: "言情后花园", baseURL: "https://www.yanqing888.com", enabled: true),
        NovelSource(id: "luoqiu", name: "落秋中文", baseURL: "https://www.luoqiu.com", enabled: true),
        NovelSource(id: "kenshu", name: "啃书网", baseURL: "https://www.kenshu5.com", enabled: true),
        NovelSource(id: "longteng", name: "龙腾小说", baseURL: "https://www.ltxt.com", enabled: true),
        NovelSource(id: "81zw", name: "八一中文", baseURL: "https://www.81zw.com", enabled: true),
        NovelSource(id: "dashubao", name: "大书包小说", baseURL: "https://www.dashubao.net", enabled: true),
        NovelSource(id: "qishu", name: "奇书网", baseURL: "https://www.qishu.cc", enabled: true),
        NovelSource(id: "quanben", name: "全本小说", baseURL: "https://www.quanben.io", enabled: true),
        NovelSource(id: "xs520", name: "小说520", baseURL: "https://www.xs520.org", enabled: true),
        NovelSource(id: "bimiku", name: "笔趣阁迷", baseURL: "https://www.bimiku.com", enabled: true),
    ]
    
    struct NovelSource: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let baseURL: String
        var enabled: Bool
    }
}

// MARK: - 小说阅读设置
class NovelSettings: ObservableObject {
    static let shared = NovelSettings()
    @AppStorage("novel_font_size") var fontSize: Double = 18
    @AppStorage("novel_line_spacing") var lineSpacing: Double = 8
    @AppStorage("novel_bg_color") var bgColorIndex: Int = 0
    @AppStorage("novel_text_color") var textColorIndex: Int = 0
    @AppStorage("novel_auto_scroll") var autoScroll: Bool = false
    @AppStorage("novel_auto_scroll_speed") var autoScrollSpeed: Double = 1.0
    
    let bgColors: [Color] = [
        Color(red:0.96,green:0.95,blue:0.90), // 护眼米黄
        Color(red:0.15,green:0.15,blue:0.15), // 夜间黑
        Color(red:0.90,green:0.95,blue:0.90), // 淡绿
        Color(red:0.95,green:0.90,blue:0.90), // 淡粉
        .white
    ]
    let textColors: [Color] = [.primary, .secondary, Color(red:0.3,green:0.3,blue:0.3)]
}

// MARK: - 小说主界面
struct NovelModuleView: View {
    @StateObject private var settings = NovelSettings.shared
    @StateObject private var sourceStore = NovelSourceStore.shared
    @State private var searchText = ""
        @State private var showSettings = false
    @State private var showSources = false
    @State private var novels: [Novel] = Novel.sampleData
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 搜索栏
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("搜索小说、作者", text: $searchText)
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
                    
                    // 分类标签
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(["全部","玄幻","都市","科幻","历史","言情","悬疑","游戏","武侠"], id: \.self) { cat in
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
                    
                    // 书架/推荐
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 16) {
                            ForEach(filteredNovels) { novel in
                                NavigationLink(value: novel) {
                                    NovelCoverCell(novel: novel)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("小说")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showSources = true } label: { Label("音源管理", systemImage: "antenna.radiowaves.left.and.right") }
                        Button { showSettings = true } label: { Label("阅读设置", systemImage: "textformat.size") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { NovelSettingsView() }
            .sheet(isPresented: $showSources) { NovelSourcesView() }
            .navigationDestination(for: Novel.self) { novel in
                NovelDetailView(novel: novel)
            }
        }
    }
    
    var filteredNovels: [Novel] {
        if searchText.isEmpty { return novels }
        return novels.filter { $0.title.contains(searchText) || $0.author.contains(searchText) }
    }
}

struct NovelCoverCell: View {
    let novel: Novel
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        VStack(spacing: 6) {
                AsyncImage(url: URL(string: novel.cover)) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(theme.accent.highlight.opacity(0.2))
                        .overlay(Image(systemName: "book.fill").foregroundColor(theme.accent.highlight))
                }
                .frame(width: 100, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
                
                Text(novel.title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
                Text(novel.author)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
    }
}

// MARK: - 小说详情
struct NovelDetailView: View {
    let novel: Novel
    @State private var chapters: [NovelChapter] = NovelChapter.sampleData
        @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 封面+信息
                HStack(alignment: .top, spacing: 16) {
                    AsyncImage(url: URL(string: novel.cover)) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(theme.accent.highlight.opacity(0.2))
                    }
                    .frame(width: 100, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(novel.title)
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        Text(novel.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Tag(text: novel.category)
                            Tag(text: novel.status)
                            Tag(text: novel.wordCount)
                        }
                        Text(novel.source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Text(novel.intro)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(4)
                    .padding(.horizontal)
                
                // 开始阅读按钮
                NavigationLink {
                    if let first = chapters.first {
                        NovelReaderView(chapters: chapters, currentIndex: 0)
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
                
                // 章节目录
                Text("章节目录")
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
        .navigationTitle(novel.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: NovelChapter.self) { chapter in
                NovelReaderView(chapters: chapters, currentIndex: chapters.firstIndex(of: chapter) ?? 0)
            }
    }
}

struct Tag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

// MARK: - 小说阅读器
struct NovelReaderView: View {
    let chapters: [NovelChapter]
    let currentIndex: Int
    @State private var currentIdx: Int
    @State private var showControls = false
    @State private var showSettings = false
    @StateObject private var settings = NovelSettings.shared
    
    init(chapters: [NovelChapter], currentIndex: Int) {
        self.chapters = chapters
        self.currentIndex = currentIndex
        _currentIdx = State(initialValue: currentIndex)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                settings.bgColors[settings.bgColorIndex].ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: settings.lineSpacing) {
                        Text(chapters[currentIdx].title)
                            .font(.title2.bold())
                            .foregroundColor(settings.textColors[settings.textColorIndex])
                            .padding(.bottom, 10)
                        
                        Text(chapters[currentIdx].content)
                            .font(.system(size: CGFloat(settings.fontSize)))
                            .foregroundColor(settings.textColors[settings.textColorIndex])
                            .lineSpacing(CGFloat(settings.lineSpacing))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onTapGesture {
                    withAnimation { showControls.toggle() }
                }
                
                // 控制栏
                if showControls {
                    VStack {
                        Spacer()
                        VStack(spacing: 0) {
                            // 章节导航
                            HStack {
                                Button {
                                    if currentIdx > 0 { currentIdx -= 1 }
                                } label: {
                                    Image(systemName: "chevron.left")
                                    Text("上一章")
                                }
                                .disabled(currentIdx == 0)
                                .foregroundColor(currentIdx == 0 ? .gray : .blue)
                                
                                Spacer()
                                
                                Text("\(currentIdx + 1)/\(chapters.count)")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Button {
                                    if currentIdx < chapters.count - 1 { currentIdx += 1 }
                                } label: {
                                    Text("下一章")
                                    Image(systemName: "chevron.right")
                                }
                                .disabled(currentIdx == chapters.count - 1)
                                .foregroundColor(currentIdx == chapters.count - 1 ? .gray : .blue)
                            }
                            .padding()
                            
                            Divider()
                            
                            // 快捷设置
                            HStack(spacing: 30) {
                                Button { settings.fontSize = max(12, settings.fontSize - 1) } label: {
                                    VStack {
                                        Image(systemName: "textformat.size.smaller")
                                        Text("减小")
                                    }
                                }
                                Button { settings.fontSize = min(28, settings.fontSize + 1) } label: {
                                    VStack {
                                        Image(systemName: "textformat.size.larger")
                                        Text("增大")
                                    }
                                }
                                Button { showSettings = true } label: {
                                    VStack {
                                        Image(systemName: "gearshape")
                                        Text("设置")
                                    }
                                }
                                Button { settings.autoScroll.toggle() } label: {
                                    VStack {
                                        Image(systemName: settings.autoScroll ? "pause.circle" : "play.circle")
                                        Text(settings.autoScroll ? "暂停" : "自动")
                                    }
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding()
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .navigationBarHidden(showControls)
        .sheet(isPresented: $showSettings) { NovelSettingsView() }
    }
}

// MARK: - 小说设置
struct NovelSettingsView: View {
    @StateObject private var settings = NovelSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("字体大小") {
                    Slider(value: $settings.fontSize, in: 12...28, step: 1) {
                        Text("字号")
                    }
                    Text("当前：\(Int(settings.fontSize))号")
                        .foregroundColor(.secondary)
                }
                
                Section("行间距") {
                    Slider(value: $settings.lineSpacing, in: 4...20, step: 1)
                    Text("当前：\(Int(settings.lineSpacing))pt")
                        .foregroundColor(.secondary)
                }
                
                Section("背景颜色") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<settings.bgColors.count, id: \.self) { i in
                                Button {
                                    settings.bgColorIndex = i
                                } label: {
                                    Circle()
                                        .fill(settings.bgColors[i])
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle().stroke(settings.bgColorIndex == i ? .blue : .clear, lineWidth: 3)
                                        )
                                }
                            }
                        }
                    }
                }
                
                Section("自动滚动") {
                    Toggle("自动翻页", isOn: $settings.autoScroll)
                    if settings.autoScroll {
                        Slider(value: $settings.autoScrollSpeed, in: 0.5...3, step: 0.5)
                        Text("速度：\(settings.autoScrollSpeed, specifier: "%.1f")x")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 小说音源管理
struct NovelSourcesView: View {
    @StateObject private var store = NovelSourceStore.shared
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
            .navigationTitle("小说音源")
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
extension Novel {
    static let sampleData: [Novel] = [
        Novel(id: "1", title: "斗破苍穹", author: "天蚕土豆", cover: "https://picsum.photos/seed/novel1/200/280", intro: "三十年河东，三十年河西，莫欺少年穷！年仅15岁的萧家废物，于此地，立下了誓言，从今以后便一步步走向斗气大陆巅峰！", category: "玄幻", status: "完结", wordCount: "530万字", source: "笔趣阁"),
        Novel(id: "2", title: "凡人修仙传", author: "忘语", cover: "https://picsum.photos/seed/novel2/200/280", intro: "一个普通的山村穷小子，偶然之下，跨入到一个江湖小门派，虽然资质平庸，但依靠自身努力和对修仙的追求，最终修炼成仙。", category: "仙侠", status: "完结", wordCount: "740万字", source: "起点镜像"),
        Novel(id: "3", title: "诡秘之主", author: "爱潜水的乌贼", cover: "https://picsum.photos/seed/novel3/200/280", intro: "蒸汽与机械的浪潮中，谁能触及非凡？历史和黑暗的迷雾里，又是谁在耳语？我从诡秘中醒来，发现自己成了唯一的愚者。", category: "玄幻", status: "完结", wordCount: "440万字", source: "纵横中文"),
        Novel(id: "4", title: "全职高手", author: "蝴蝶蓝", cover: "https://picsum.photos/seed/novel4/200/280", intro: "网游荣耀中被誉为教科书级别的顶尖高手，因为种种原因遭到俱乐部的驱逐，离开职业圈的他寄身于一家网吧成了一个小小的网管。", category: "游戏", status: "完结", wordCount: "530万字", source: "晋江文学"),
        Novel(id: "5", title: "盗墓笔记", author: "南派三叔", cover: "https://picsum.photos/seed/novel5/200/280", intro: "五十年前，一群长沙土夫子挖到了一部战国帛书，残篇中记载了一座奇特的战国古墓的位置，但那群土夫子在地下碰上了诡异事件。", category: "悬疑", status: "完结", wordCount: "400万字", source: "番茄小说"),
        Novel(id: "6", title: "庆余年", author: "猫腻", cover: "https://picsum.photos/seed/novel6/200/280", intro: "积善之家，必有余庆，留余庆，留余庆，忽遇恩人；幸娘亲，幸娘亲，积得阴功。劝人生，济困扶穷。", category: "历史", status: "完结", wordCount: "380万字", source: "新笔趣阁"),
    ]
}

extension NovelChapter {
    static let sampleData: [NovelChapter] = [
        NovelChapter(id: "1", title: "第一章 陨落的天才", content: "斗气大陆，斗气决定一切。\n\n萧家，加玛帝国东北部的乌坦城三大家族之一。\n\n萧炎，萧家历史上前所未有的修炼奇才，四岁练气，十岁拥有九段斗之气，十一岁突破十段斗之气，成功凝聚斗之气旋，一跃成为家族百年之内最年轻的斗者！\n\n然而，天才的道路总是充满坎坷。在十二岁那年，一场突如其来的变故，让他的修为一夜之间倒退到了三段斗之气。\n\n三年的时间，他从云端跌落泥潭，受尽了族人的白眼和嘲讽。\n\n\"萧炎，三段斗之气！\"测试员冷漠的声音在广场上回荡。\n\n人群中爆发出一阵哄笑，那些曾经羡慕嫉妒的目光，如今变成了赤裸裸的鄙夷。\n\n萧炎紧紧握着拳头，指甲深深陷入掌心，鲜血顺着指缝滴落。他的眼中没有泪水，只有不屈的火焰。\n\n\"三十年河东，三十年河西，莫欺少年穷！\"\n\n他在心中默默发誓，总有一天，他会重新站在巅峰，让所有看不起他的人仰望！"),
        NovelChapter(id: "2", title: "第二章 神秘戒指", content: "回到自己的小屋，萧炎盘膝坐在床上，开始了今天的修炼。\n\n然而，无论他如何努力，斗气在经脉中运转一圈后，总会莫名其妙地消散大半。\n\n这种情况已经持续了三年。\n\n\"又是这样...\"萧炎无奈地叹了口气。\n\n就在他准备放弃的时候，手指上那枚母亲留下的黑色戒指突然微微发烫。\n\n一道苍老的声音在他脑海中响起：\"小子，别白费力气了，你的斗气都被我吸收了。\"\n\n萧炎猛地睁开眼睛，惊恐地看着戒指：\"谁？！\"\n\n\"老夫药尘，曾经也是这片大陆上赫赫有名的人物。\"戒指上浮现出一个模糊的老者虚影，\"要不是你这三年来的斗气滋养，老夫还不知道要沉睡到什么时候。\"\n\n\"你吸收了我的斗气？！\"萧炎又惊又怒。\n\n\"放心，老夫不会白拿你的。\"药尘淡淡一笑，\"从今天起，老夫收你为徒，传你无上炼药术和修炼功法，保你重回巅峰，甚至超越从前！\""),
        NovelChapter(id: "3", title: "第三章 药老", content: "萧炎半信半疑地看着戒指上的老者虚影。\n\n\"你真的能帮我？\"\n\n\"小子，你可知道老夫当年的名号？\"药尘傲然道，\"药尊者药尘，斗气大陆上首屈一指的炼药宗师！多少斗皇、斗宗级别的强者，都要对老夫客客气气！\"\n\n萧炎的眼睛亮了起来。炼药师，那可是斗气大陆上最尊贵的职业！一个高级炼药师，足以让无数强者趋之若鹜。\n\n\"好！我拜你为师！\"萧炎毫不犹豫地跪下磕头。\n\n\"哈哈哈，好！\"药尘满意地大笑，\"从今天起，你就是我药尘的唯一弟子！老夫这里有一部功法，名为《焚诀》，修炼到极致，可吞天地异火，威力无穷！\"\n\n萧炎接过功法，只看了几眼，就被其中博大精深的内容深深吸引。\n\n\"这部功法...太厉害了！\"\n\n\"那是自然。\"药尘捋着胡须，\"不过，修炼《焚诀》需要异火，这东西可遇不可求。在那之前，老夫先教你炼药之术，有了炼药师的身份，你才能在这片大陆上立足。\"\n\n萧炎重重点头，眼中重新燃起了希望的火焰。三年的屈辱，三年的等待，终于在今天迎来了转机！"),
    ]
}
