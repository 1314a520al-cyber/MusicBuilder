import SwiftUI

struct ReaderView: View {
    let novel: Novel
    let chapters: [NovelChapter]
    let startIndex: Int
    
    private var bookshelf: BookshelfStore { BookshelfStore.shared }
    private var theme: NovelTheme { NovelTheme.shared }
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentIndex: Int
    @State private var content: ChapterContent?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showMenu = false
    @State private var showChapterList = false
    @State private var showSettings = false
    @State private var showDownloadSheet = false
    @State private var scrollProgress: Double = 0
    
    init(novel: Novel, chapters: [NovelChapter], startIndex: Int) {
        self.novel = novel
        self.chapters = chapters
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                theme.bgColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部栏
                    topBar
                    
                    // 内容区
                    if isLoading {
                        loadingView
                    } else if let error = loadError {
                        errorView(error)
                    } else if let content = content {
                        contentView(content, geo: geo)
                    }
                    
                    // 底部栏
                    bottomBar
                }
                .opacity(showMenu ? 0.3 : 1)
                
                // 菜单覆盖层
                if showMenu {
                    menuOverlay
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            loadChapter()
        }
        .sheet(isPresented: $showChapterList) {
            ChapterListView(novel: novel, chapters: chapters, onSelect: { index in
                showChapterList = false
                currentIndex = index
                loadChapter()
            })
        }
        .sheet(isPresented: $showSettings) {
            ReadingSettingsView()
                .environmentObject(theme)
        }
        .sheet(isPresented: $showDownloadSheet) {
            if let content = content {
                SingleChapterDownloadView(novel: novel, chapter: chapters[currentIndex], content: content.content)
            }
        }
    }
    
    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            Button {
                saveProgress()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.textColor)
                    .frame(width: 40, height: 40)
            }
            
            VStack(spacing: 2) {
                Text(novel.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textColor)
                    .lineLimit(1)
                if !chapters.isEmpty {
                    Text(chapters[currentIndex].title)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textColor.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button {
                showChapterList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.textColor)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(theme.bgColor.opacity(0.95))
    }
    
    // MARK: - 内容区
    private func contentView(_ content: ChapterContent, geo: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 章节标题
                    Text(content.title)
                        .font(.system(size: theme.fontSize + 4, weight: .bold))
                        .foregroundStyle(theme.textColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 24)
                    
                    // 正文
                    Text(content.content)
                        .font(.system(size: theme.fontSize))
                        .foregroundStyle(theme.textColor)
                        .lineSpacing(theme.lineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 底部间距
                    Color.clear.frame(height: 60)
                    
                    // 下一章按钮
                    if currentIndex < chapters.count - 1 {
                        Button {
                            currentIndex += 1
                            loadChapter()
                        } label: {
                            HStack {
                                Spacer()
                                Text("下一章")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    } else {
                        Text("已是最后一章")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textColor.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMenu.toggle()
                }
            }
            .onAppear {
                // 恢复阅读进度
                if let record = bookshelf.getProgress(novelId: novel.id),
                   record.chapterIndex == currentIndex {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let offset = record.progress * 1000
                        proxy.scrollTo(1, anchor: UnitPoint(x: 0, y: offset / 1000))
                    }
                }
            }
        }
    }
    
    // MARK: - 底部栏
    private var bottomBar: some View {
        HStack(spacing: 0) {
            Button {
                if currentIndex > 0 {
                    currentIndex -= 1
                    loadChapter()
                }
            } label: {
                Image(systemName: "chevron.left.2")
                    .font(.system(size: 18))
                    .foregroundStyle(currentIndex > 0 ? theme.textColor : theme.textColor.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(currentIndex == 0)
            
            Button {
                showSettings = true
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.textColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            
            Button {
                showDownloadSheet = true
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.textColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            
            Button {
                showChapterList = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.textColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            
            Button {
                if currentIndex < chapters.count - 1 {
                    currentIndex += 1
                    loadChapter()
                }
            } label: {
                Image(systemName: "chevron.right.2")
                    .font(.system(size: 18))
                    .foregroundStyle(currentIndex < chapters.count - 1 ? theme.textColor : theme.textColor.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(currentIndex == chapters.count - 1)
        }
        .background(theme.bgColor.opacity(0.95))
    }
    
    // MARK: - 菜单覆盖层
    private var menuOverlay: some View {
        Color.black.opacity(0.001)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMenu = false
                }
            }
    }
    
    // MARK: - 加载/错误
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(theme.textColor)
            Text("加载中...")
                .foregroundStyle(theme.textColor.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(error)
                .foregroundStyle(theme.textColor.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("重试") {
                loadChapter()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
    
    // MARK: - 加载章节
    private func loadChapter() {
        isLoading = true
        loadError = nil
        content = nil
        
        guard currentIndex < chapters.count else {
            loadError = "章节索引越界"
            isLoading = false
            return
        }
        
        let chapter = chapters[currentIndex]
        Task {
            do {
                let chapterContent = try await NovelAPI.shared.getChapterContent(url: chapter.url)
                await MainActor.run {
                    content = chapterContent
                    isLoading = false
                    saveProgress()
                }
            } catch {
                await MainActor.run {
                    loadError = "加载失败：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func saveProgress() {
        bookshelf.updateProgress(novelId: novel.id, chapterIndex: currentIndex, progress: scrollProgress)
    }
}
