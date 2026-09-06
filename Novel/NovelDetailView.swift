import SwiftUI

struct NovelDetailView: View {
    let novel: Novel
    let onRead: ([NovelChapter], Int) -> Void
    private var bookshelf: BookshelfStore { BookshelfStore.shared }
    @Environment(\.dismiss) private var dismiss
    
    @State private var detailedNovel: Novel?
    @State private var chapters: [NovelChapter] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showChapterList = false
    @State private var showDownloadSheet = false
    @State private var selectedFolder = "默认"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    loadingView
                } else if let error = loadError {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle(detailedNovel?.title ?? novel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showChapterList) {
                ChapterListView(novel: detailedNovel ?? novel, chapters: chapters, onSelect: { index in
                    showChapterList = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onRead(chapters, index)
                    }
                })
            }
            .sheet(isPresented: $showDownloadSheet) {
                DownloadFolderSelectView(novel: detailedNovel ?? novel, chapters: chapters)
            }
            .onAppear {
                loadDetail()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text(error)
                .foregroundStyle(.secondary)
            Button("重试") {
                loadDetail()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 书籍信息
            bookInfoSection
            
            // 简介
            introSection
            
            // 最新章节
            latestChapterSection
            
            // 操作按钮
            actionButtons
            
            // 章节目录预览
            chapterPreview
        }
    }
    
    private var bookInfoSection: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [.orange.opacity(0.6), .red.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 100, height: 140)
                .overlay {
                    if let cover = detailedNovel?.coverURL, let url = URL(string: cover) {
                        AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { ProgressView() }
                            .clipped()
                    } else {
                        Text((detailedNovel?.title ?? novel.title).prefix(1))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .cornerRadius(10)
                .shadow(radius: 5)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(detailedNovel?.title ?? novel.title)
                    .font(.system(size: 20, weight: .bold))
                    .lineLimit(2)
                Text(detailedNovel?.author ?? novel.author)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if let cat = detailedNovel?.category ?? novel.category {
                        Text(cat)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .cornerRadius(4)
                    }
                    if let status = detailedNovel?.status ?? novel.status {
                        Text(status)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .cornerRadius(4)
                    }
                }
                if let last = detailedNovel?.lastChapter {
                    Text("最新：\(last)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }
    
    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)
            Text(detailedNovel?.intro ?? novel.intro ?? "暂无简介")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var latestChapterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最新章节")
                    .font(.headline)
                Spacer()
                Button("全部目录") {
                    showChapterList = true
                }
                .font(.system(size: 14))
                .foregroundStyle(.orange)
            }
            if let last = chapters.last {
                Text(last.title)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                if bookshelf.isInShelf(detailedNovel ?? novel) {
                    bookshelf.removeBook(detailedNovel ?? novel)
                } else {
                    bookshelf.addBook(detailedNovel ?? novel)
                }
            } label: {
                HStack {
                    Image(systemName: bookshelf.isInShelf(detailedNovel ?? novel) ? "checkmark" : "plus")
                    Text(bookshelf.isInShelf(detailedNovel ?? novel) ? "已收藏" : "加入书架")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(bookshelf.isInShelf(detailedNovel ?? novel) ? Color.gray.opacity(0.15) : Color.orange)
                .foregroundColor(bookshelf.isInShelf(detailedNovel ?? novel) ? .primary : .white)
                .cornerRadius(12)
            }
            
            Button {
                showDownloadSheet = true
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("下载整本")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.15))
                .foregroundStyle(.primary)
                .cornerRadius(12)
            }
            
            Button {
                let startIndex = bookshelf.getProgress(novelId: novel.id)?.chapterIndex ?? 0
                onRead(chapters, min(startIndex, chapters.count - 1))
            } label: {
                HStack {
                    Image(systemName: "book.fill")
                    Text(bookshelf.getProgress(novelId: novel.id) != nil ? "继续阅读" : "开始阅读")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var chapterPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("章节目录")
                .font(.headline)
                .padding(.horizontal, 16)
            
            ForEach(chapters.prefix(10)) { chapter in
                Button {
                    if let index = chapters.firstIndex(where: { $0.id == chapter.id }) {
                        onRead(chapters, index)
                    }
                } label: {
                    HStack {
                        Text(chapter.title)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                Divider()
                    .padding(.leading, 16)
            }
            
            if chapters.count > 10 {
                Button {
                    showChapterList = true
                } label: {
                    HStack {
                        Spacer()
                        Text("查看全部 \(chapters.count) 章")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    private func loadDetail() {
        isLoading = true
        loadError = nil
        Task {
            do {
                let (detail, chapterList) = try await NovelAPI.shared.getNovelDetail(novel: novel)
                await MainActor.run {
                    detailedNovel = detail
                    chapters = chapterList
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = "加载失败：\(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct ChapterListView: View {
    let novel: Novel
    let chapters: [NovelChapter]
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredChapters: [NovelChapter] {
        if searchText.isEmpty { return chapters }
        return chapters.filter { $0.title.contains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索章节", text: $searchText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                List {
                    ForEach(filteredChapters) { chapter in
                        Button {
                            if let index = chapters.firstIndex(where: { $0.id == chapter.id }) {
                                onSelect(index)
                            }
                        } label: {
                            HStack {
                                Text(chapter.title)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("目录（\(chapters.count)章）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
