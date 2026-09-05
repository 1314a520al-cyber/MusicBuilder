import SwiftUI

// MARK: - 大纲
struct OutlineView: View {
    @EnvironmentObject var store: DataStore
    let book: Book
    @State private var outline: String

    init(book: Book) {
        self.book = book
        _outline = State(initialValue: book.outline)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $outline)
                .font(.body)
                .padding()
                .onChange(of: outline) { _ in save() }
        }
        .navigationTitle("大纲")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: generateAIGenerate) {
                        Label("AI 生成大纲", systemImage: "wand.and.stars")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func save() {
        var b = book
        b.outline = outline
        store.updateBook(b)
    }

    private func generateAIGenerate() {
        Task {
            do {
                let result = try await AIClient.shared.generateOutline(topic: book.title + (book.description.isEmpty ? "" : "：\(book.description)"), settings: store.aiSettings)
                await MainActor.run {
                    outline = result
                    save()
                }
            } catch {}
        }
    }
}

// MARK: - 角色
struct CharactersView: View {
    @EnvironmentObject var store: DataStore
    let book: Book
    @State private var showAdd = false
    @State private var editingCharacter: Character?

    private var currentBook: Book {
        store.books.first { $0.id == book.id } ?? book
    }

    var body: some View {
        List {
            if currentBook.characters.isEmpty {
                Text("还没有角色，点击右上角添加")
                    .foregroundColor(.gray)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(currentBook.characters) { char in
                    Button(action: { editingCharacter = char }) {
                        HStack(spacing: 12) {
                            if let data = char.avatarData, let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(char.name.prefix(1))
                                            .font(.headline)
                                    )
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(char.name)
                                    .font(.headline)
                                if !char.role.isEmpty {
                                    Text(char.role)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .onDelete { indexSet in
                    var b = currentBook
                    b.characters.remove(atOffsets: indexSet)
                    store.updateBook(b)
                }
            }
        }
        .navigationTitle("角色")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAdd = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            CharacterEditView(book: currentBook, character: nil)
        }
        .sheet(item: $editingCharacter) { char in
            CharacterEditView(book: currentBook, character: char)
        }
    }
}

struct CharacterEditView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    let character: Character?
    @State private var name: String
    @State private var role: String
    @State private var description: String
    @State private var relations: String

    init(book: Book, character: Character?) {
        self.book = book
        self.character = character
        _name = State(initialValue: character?.name ?? "")
        _role = State(initialValue: character?.role ?? "")
        _description = State(initialValue: character?.description ?? "")
        _relations = State(initialValue: character?.relations.joined(separator: "、") ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("角色名", text: $name)
                TextField("身份/定位", text: $role)
                TextField("人物关系（用、分隔）", text: $relations)
                TextField("角色描述", text: $description, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle(character == nil ? "添加角色" : "编辑角色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var b = book
                        let char = Character(
                            id: character?.id ?? UUID(),
                            name: name,
                            role: role,
                            description: description,
                            relations: relations.components(separatedBy: "、").filter { !$0.isEmpty }
                        )
                        if let idx = b.characters.firstIndex(where: { $0.id == char.id }) {
                            b.characters[idx] = char
                        } else {
                            b.characters.append(char)
                        }
                        store.updateBook(b)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - 设定
struct WorldSettingsView: View {
    @EnvironmentObject var store: DataStore
    let book: Book
    @State private var showAdd = false
    @State private var editingSetting: WorldSetting?

    private var currentBook: Book {
        store.books.first { $0.id == book.id } ?? book
    }

    var body: some View {
        List {
            if currentBook.settings.isEmpty {
                Text("还没有设定，点击右上角添加")
                    .foregroundColor(.gray)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(currentBook.settings) { setting in
                    Button(action: { editingSetting = setting }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(setting.title)
                                    .font(.headline)
                                Spacer()
                                Text(setting.category)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            if !setting.content.isEmpty {
                                Text(setting.content)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    var b = currentBook
                    b.settings.remove(atOffsets: indexSet)
                    store.updateBook(b)
                }
            }
        }
        .navigationTitle("设定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAdd = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            SettingEditView(book: currentBook, setting: nil)
        }
        .sheet(item: $editingSetting) { setting in
            SettingEditView(book: currentBook, setting: setting)
        }
    }
}

struct SettingEditView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    let setting: WorldSetting?
    @State private var title: String
    @State private var content: String
    @State private var category: String

    private let categories = ["世界观", "势力", "功法", "物品", "地点", "其他"]

    init(book: Book, setting: WorldSetting?) {
        self.book = book
        self.setting = setting
        _title = State(initialValue: setting?.title ?? "")
        _content = State(initialValue: setting?.content ?? "")
        _category = State(initialValue: setting?.category ?? "世界观")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("设定标题", text: $title)
                Picker("分类", selection: $category) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                TextField("设定内容", text: $content, axis: .vertical)
                    .lineLimit(4...12)
            }
            .navigationTitle(setting == nil ? "添加设定" : "编辑设定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var b = book
                        let s = WorldSetting(id: setting?.id ?? UUID(), title: title, content: content, category: category)
                        if let idx = b.settings.firstIndex(where: { $0.id == s.id }) {
                            b.settings[idx] = s
                        } else {
                            b.settings.append(s)
                        }
                        store.updateBook(b)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - 时间线
struct TimelineView: View {
    @EnvironmentObject var store: DataStore
    let book: Book
    @State private var showAdd = false

    private var currentBook: Book {
        store.books.first { $0.id == book.id } ?? book
    }

    var body: some View {
        List {
            if currentBook.timeline.isEmpty {
                Text("还没有时间线事件，点击右上角添加")
                    .foregroundColor(.gray)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(currentBook.timeline.sorted { $0.date < $1.date }) { event in
                    HStack(alignment: .top, spacing: 12) {
                        VStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 2)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.date)
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(event.event)
                                .font(.headline)
                            if !event.description.isEmpty {
                                Text(event.description)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    let sorted = currentBook.timeline.sorted { $0.date < $1.date }
                    for idx in indexSet {
                        var b = currentBook
                        b.timeline.removeAll { $0.id == sorted[idx].id }
                        store.updateBook(b)
                    }
                }
            }
        }
        .navigationTitle("时间线")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAdd = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            TimelineEditView(book: currentBook)
        }
    }
}

struct TimelineEditView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let book: Book
    @State private var date = ""
    @State private var event = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("时间（如：第一章 第三年）", text: $date)
                TextField("事件", text: $event)
                TextField("详细描述", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("添加事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var b = book
                        b.timeline.append(TimelineEvent(date: date, event: event, description: description))
                        store.updateBook(b)
                        dismiss()
                    }
                    .disabled(date.isEmpty || event.isEmpty)
                }
            }
        }
    }
}
