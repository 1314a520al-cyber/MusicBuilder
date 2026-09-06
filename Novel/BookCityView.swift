import SwiftUI

struct BookCityView: View {
    private var theme: NovelTheme { NovelTheme.shared }
    private var sourceManager: NovelSourceManager { NovelSourceManager.shared }
    @State private var selectedCategory = "全部"
    @State private var showDetail: Novel?
    @State private var showReader: (Novel, [NovelChapter], Int)?
    @State private var hotNovels: [Novel] = []
    @State private var isLoading = false
    @State private var loadError = ""
    
    // 示例小说（源不可用时显示）
    private let sampleNovels: [Novel] = [
        Novel(id: "sample1", title: "斗破苍穹", author: "天蚕土豆", coverURL: nil, intro: "三十年河东，三十年河西，莫欺少年穷！", sourceId: "sample", bookUrl: "https://www.biquge.co/book/1", lastChapter: "第1648章 大结局", updateTime: nil, category: "玄幻", status: "完结"),
        Novel(id: "sample2", title: "完美世界", author: "辰东", coverURL: nil, intro: "一粒尘可填海，一根草斩尽日月星辰。", sourceId: "sample", bookUrl: "https://www.biquge.co/book/2", lastChapter: "第2014章 完美终章", updateTime: nil, category: "玄幻", status: "完结"),
        Novel(id: "sample3", title: "遮天", author: "辰东", coverURL: nil, intro: "冰冷与黑暗并存的宇宙深处，九具庞大的龙尸拉着一口青铜古棺。", sourceId: "sample", bookUrl: "https://www.biquge.co/book/3", lastChapter: "第1880章 终章", updateTime: nil, category: "玄幻", status: "完结"),
        Novel(id: "sample4", title: "凡人修仙传", author: "忘语", coverURL: nil, intro: "一个普通山村少年，偶然下进入到当地江湖小门派。", sourceId: "sample", bookUrl: "https://www.biquge.co/book/4", lastChapter: "第2448章 大结局", updateTime: nil, category: "仙侠", status: "完结"),
        Novel(id: "sample5", title: "诡秘之主", author: "爱潜水的乌贼", coverURL: nil, intro: "蒸汽与机械的浪潮中，谁能触及非凡？", sourceId: "sample", bookUrl: "https://www.biquge.co/book/5", lastChapter: "第1432章 大结局", updateTime: nil, category: "玄幻", status: "完结"),
        Novel(id: "sample6", title: "庆余年", author: "猫腻", coverURL: nil, intro: "积善之家，必有余庆，留余庆，留余庆，忽遇恩人。", sourceId: "sample", bookUrl: "https://www.biquge.co/book/6", lastChapter: "未完待续", updateTime: nil, category: "历史", status: "连载"),
    ]
    
    let categories = ["全部", "玄幻", "都市", "言情", "历史", "科幻", "武侠", "悬疑", "游戏", "其他"]
    let hotKeywords = ["斗破苍穹", "完美世界", "遮天", "凡人修仙传", "诡秘之主", "庆余年", "雪中悍刀行", "剑来"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 轮播图
                        bannerView
                        
                        // 分类横滑
                        categorySection
                        
                        // 热门推荐
                        hotSection
                        
                        // 精选小说
                        featuredSection
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("书城")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                loadHotNovels()
            }
            .onAppear {
                if hotNovels.isEmpty {
                    // 立即显示示例小说，避免空白
                    hotNovels = sampleNovels
                    loadHotNovels()
                }
            }
            .sheet(item: $showDetail) { novel in
                NovelDetailView(novel: novel, onRead: { chapters, index in
                    showReader = (novel, chapters, index)
                })
            }
            .sheet(item: Binding(
                get: { showReader.map { ReaderSheetData(novel: $0.0, chapters: $0.1, startIndex: $0.2) } },
                set: { showReader = $0.map { ($0.novel, $0.chapters, $0.startIndex) } }
            )) { data in
                ReaderView(novel: data.novel, chapters: data.chapters, startIndex: data.startIndex)
            }
        }
    }
    
    private var bannerView: some View {
        TabView {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        colors: [theme.accentColor.opacity(0.6), theme.accentColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay {
                        VStack(spacing: 8) {
                            Text(["热门小说推荐", "精选好书", "新书速递"][index])
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("海量免费小说，随心阅读")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 16)
            }
        }
        .frame(height: 140)
        .tabViewStyle(.page(indexDisplayMode: .always))
        .padding(.top, 8)
    }
    
    @State private var showCategories = false
    
    private var categorySection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut) {
                    showCategories.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(theme.accentColor)
                    Text("分类")
                        .font(.headline)
                    Spacer()
                    Text(selectedCategory)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: showCategories ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            if showCategories {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                            withAnimation(.easeInOut) {
                                showCategories = false
                            }
                        } label: {
                            Text(cat)
                                .font(.system(size: 13, weight: selectedCategory == cat ? .bold : .regular))
                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedCategory == cat ? theme.accentColor : Color.gray.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private var hotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔥 热门推荐")
                    .font(.title2.bold())
                Spacer()
                if isLoading {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)
            
            if !loadError.isEmpty {
                Text(loadError)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .multilineTextAlignment(.leading)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(hotNovels.prefix(15)) { novel in
                        BookCoverCell(novel: novel)
                            .frame(width: 100)
                            .onTapGesture {
                                showDetail = novel
                            }
                    }
                    if hotNovels.isEmpty && !isLoading {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 100, height: 150)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(selectedCategory == "全部" ? "✨ 精选" : selectedCategory)小说")
                .font(.title2.bold())
                .padding(.horizontal, 16)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(hotNovels.dropFirst(3).prefix(18)) { novel in
                    BookCoverCell(novel: novel)
                        .onTapGesture {
                            showDetail = novel
                        }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func loadHotNovels() {
        isLoading = true
        loadError = ""
        Task {
            let sources = sourceManager.enabledSources()
            var allNovels: [Novel] = []
            do {
                // 只搜索2个关键词，加快加载速度
                for keyword in hotKeywords.prefix(2) {
                    let results = try await NovelAPI.shared.searchNovels(keyword: keyword, sources: sources)
                    allNovels.append(contentsOf: results.prefix(5))
                }
            } catch {
                loadError = error.localizedDescription
            }
            await MainActor.run {
                if allNovels.isEmpty {
                    // 源不可用时保持示例小说
                    loadError = "内置源暂不可用，当前显示示例小说。请在【我的-小说源管理】中添加或导入可用书源。"
                } else {
                    hotNovels = allNovels
                    loadError = ""
                }
                isLoading = false
            }
        }
    }
}

// 书籍封面Cell
struct BookCoverCell: View {
    let novel: Novel
    @ObservedObject private var theme = NovelTheme.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [theme.accentColor.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .aspectRatio(3/4, contentMode: .fit)
                
                Text(novel.title.prefix(2))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Text(novel.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.white)
            
            Text(novel.author)
                .font(.system(size: 10))
                .lineLimit(1)
                .foregroundStyle(.gray)
        }
    }
}
