import SwiftUI

struct SearchView: View {
    private var theme: NovelTheme { NovelTheme.shared }
    private var sourceManager: NovelSourceManager { NovelSourceManager.shared }
    @State private var keyword = ""
    @State private var results: [Novel] = []
    @State private var isSearching = false
    @State private var showDetail: Novel?
    @State private var showReader: (Novel, [NovelChapter], Int)?
    @State private var searchHistory: [String] = []
    
    let hotSearches = ["斗破苍穹", "完美世界", "遮天", "凡人修仙传", "诡秘之主", "庆余年", "雪中悍刀行", "剑来", "斗罗大陆", "盗墓笔记"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidGlassBackground()
                
                VStack(spacing: 0) {
                    searchBar
                    
                    if results.isEmpty && !isSearching {
                        suggestionView
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.large)
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
            .onAppear {
                searchHistory = UserDefaults.standard.stringArray(forKey: "novel.searchHistory") ?? []
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索小说、作者", text: $keyword)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            Button("搜索") {
                performSearch()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(theme.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var suggestionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("搜索历史")
                                .font(.headline)
                            Spacer()
                            Button {
                                searchHistory = []
                                UserDefaults.standard.removeObject(forKey: "novel.searchHistory")
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        FlowLayout(spacing: 8) {
                            ForEach(searchHistory, id: \.self) { word in
                                Button {
                                    keyword = word
                                    performSearch()
                                } label: {
                                    Text(word)
                                        .font(.system(size: 13))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(16)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔥 热门搜索")
                        .font(.headline)
                    FlowLayout(spacing: 8) {
                        ForEach(hotSearches, id: \.self) { word in
                            Button {
                                keyword = word
                                performSearch()
                            } label: {
                                Text(word)
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(theme.accentColor.opacity(0.12))
                                    .cornerRadius(16)
                                    .foregroundStyle(theme.accentColor)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .padding(.top, 8)
        }
    }
    
    private var resultsList: some View {
        List {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView("搜索中...")
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if results.isEmpty {
                Text("没有找到相关小说")
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(results) { novel in
                    NovelSearchRow(novel: novel)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showDetail = novel
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
                .padding(.bottom, 100)
    }
    
    private func performSearch() {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        dismissKeyboard()
        isSearching = true
        results = []
        
        if !searchHistory.contains(keyword) {
            searchHistory.insert(keyword, at: 0)
            if searchHistory.count > 20 { searchHistory.removeLast() }
            UserDefaults.standard.set(searchHistory, forKey: "novel.searchHistory")
        }
        
        Task {
            let sources = sourceManager.enabledSources()
            do {
                let found = try await NovelAPI.shared.searchNovels(keyword: keyword, sources: sources)
                await MainActor.run {
                    results = found
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }
}

struct NovelSearchRow: View {
    let novel: Novel
    private var theme: NovelTheme { NovelTheme.shared }
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [theme.accentColor.opacity(0.6), theme.accentColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 60, height: 80)
                .overlay {
                    if let cover = novel.coverURL, let url = URL(string: cover) {
                        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { ProgressView() }
                            .clipped()
                    } else {
                        Text(novel.title.prefix(1))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(novel.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                Text(novel.author)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if let intro = novel.intro, !intro.isEmpty {
                    Text(intro)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height = y + rowHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

extension View {
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
