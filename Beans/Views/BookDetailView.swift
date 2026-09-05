import SwiftUI

struct BookDetailView: View {
    @EnvironmentObject var store: DataStore
    let book: Book
    @State private var showAddChapter = false
    @State private var newChapterTitle = ""
    @State private var showEditBook = false
    @State private var showOutline = false
    @State private var showCharacters = false
    @State private var showSettings = false
    @State private var showTimeline = false
    @State private var showExport = false

    private var currentBook: Book {
        store.books.first { $0.id == book.id } ?? book
    }

    var body: some View {
        List {
            Section("作品信息") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentBook.title)
                            .font(.title2.bold())
                        if !currentBook.author.isEmpty {
                            Text("作者：\(currentBook.author)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Text("共 \(currentBook.chapters.count) 章 · \(currentBook.totalWords) 字")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                if !currentBook.description.isEmpty {
                    Text(currentBook.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            Section("参考资料") {
                NavigationLink(destination: OutlineView(book: currentBook)) {
                    Label("大纲", systemImage: "list.bullet.clipboard")
                }
                NavigationLink(destination: CharactersView(book: currentBook)) {
                    Label("角色", systemImage: "person.2")
                }
                NavigationLink(destination: WorldSettingsView(book: currentBook)) {
                    Label("设定", systemImage: "globe")
                }
                NavigationLink(destination: TimelineView(book: currentBook)) {
                    Label("时间线", systemImage: "clock")
                }
            }

            Section("章节列表") {
                if currentBook.chapters.isEmpty {
                    Text("还没有章节，点击下方按钮创建")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(currentBook.chapters) { chapter in
                        NavigationLink(destination: ChapterEditView(bookId: currentBook.id, chapter: chapter)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.body)
                                HStack {
                                    Text("\(chapter.wordCount) 字")
                                    Text(chapter.updatedAt, style: .date)
                                }
                                .font(.caption2)
                                .foregroundColor(.gray)
                            }
                        }
                    }
                    .onMove { source, dest in
                        store.moveChapter(in: currentBook.id, from: source, to: dest)
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            store.deleteChapter(from: currentBook.id, currentBook.chapters[idx].id)
                        }
                    }
                }
                Button(action: { showAddChapter = true }) {
                    Label("新建章节", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(currentBook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showEditBook = true }) {
                        Label("编辑信息", systemImage: "pencil")
                    }
                    Button(action: { showExport = true }) {
                        Label("导出作品", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddChapter) {
            addChapterSheet
        }
        .sheet(isPresented: $showEditBook) {
            EditBookView(book: currentBook)
        }
        .sheet(isPresented: $showExport) {
            ExportView(book: currentBook)
        }
    }

    private var addChapterSheet: some View {
        NavigationStack {
            Form {
                TextField("章节标题", text: $newChapterTitle)
            }
            .navigationTitle("新建章节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAddChapter = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        if !newChapterTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.addChapter(to: currentBook.id, title: newChapterTitle.trimmingCharacters(in: .whitespaces))
                            newChapterTitle = ""
                            showAddChapter = false
                        }
                    }
                    .disabled(newChapterTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - 编辑作品
struct EditBookView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var title: String
    @State private var author: String
    @State private var description: String
    @State private var category: String
    @State private var dailyTarget: Int

    init(book: Book) {
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _description = State(initialValue: book.description)
        _category = State(initialValue: book.category)
        _dailyTarget = State(initialValue: book.dailyTarget)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("书名", text: $title)
                    TextField("作者", text: $author)
                    TextField("分类", text: $category)
                    TextField("简介", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("写作目标") {
                    Stepper("每日目标：\(dailyTarget) 字", value: $dailyTarget, in: 500...20000, step: 500)
                }
            }
            .navigationTitle("编辑作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var b = book
                        b.title = title
                        b.author = author
                        b.description = description
                        b.category = category
                        b.dailyTarget = dailyTarget
                        store.updateBook(b)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 导出
struct ExportView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var exportedURL: URL?
    @State private var showActivity = false

    var body: some View {
        NavigationStack {
            List {
                Button("导出为 TXT") {
                    if let url = store.exportBookAsTXT(book) {
                        exportedURL = url
                        showActivity = true
                    }
                }
                Button("导出为 JSON（含全部数据）") {
                    if let url = store.exportBookAsJSON(book) {
                        exportedURL = url
                        showActivity = true
                    }
                }
            }
            .navigationTitle("导出作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showActivity) {
                if let url = exportedURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
