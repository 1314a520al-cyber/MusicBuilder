import SwiftUI

struct ChapterEditView: View {
    @EnvironmentObject var store: DataStore
    let bookId: UUID
    @State var chapter: Chapter
    @State private var text: String
    @State private var showAITools = false
    @State private var showAIChat = false
    @State private var showHistory = false
    @State private var showSearch = false
    @State private var selectedRange: UITextRange?
    @State private var selectedText = ""
    @State private var wordCountAtStart: Int
    @State private var sessionStartTime = Date()
    @State private var showSensitiveAlert = false
    @State private var sensitiveFound: [String] = []
    @State private var aiResult = ""
    @State private var isAIProcessing = false
    @State private var aiChatMessages: [AIMessage] = []
    @State private var aiInput = ""
    @State private var showFocusMode = false
    @State private var autoSaveTimer: Timer?

    init(bookId: UUID, chapter: Chapter) {
        self.bookId = bookId
        _chapter = State(initialValue: chapter)
        _text = State(initialValue: chapter.content)
        _wordCountAtStart = State(initialValue: chapter.content.count)
    }

    private var currentBook: Book {
        store.books.first { $0.id == bookId } ?? Book(title: "")
    }

    var body: some View {
        ZStack {
            writingSurface

            if showFocusMode {
                focusOverlay
            }
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setupAutoSave() }
        .onDisappear { saveAndRecord(); autoSaveTimer?.invalidate() }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showSearch = true }) {
                    Image(systemName: "magnifyingglass")
                }
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                }
                Menu {
                    Button(action: { showAITools = true }) {
                        Label("AI 工具", systemImage: "wand.and.stars")
                    }
                    Button(action: { showAIChat = true }) {
                        Label("AI 对话", systemImage: "bubble.left.and.bubble.right")
                    }
                    Button(action: { toggleFocusMode() }) {
                        Label(showFocusMode ? "退出专注" : "专注模式", systemImage: "eye")
                    }
                    Button(action: { checkSensitiveWords() }) {
                        Label("敏感词检测", systemImage: "exclamationmark.shield")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAITools) { AIToolsView(text: $text, selectedText: selectedText, onApply: { newText in text = newText }) }
        .sheet(isPresented: $showAIChat) { AIChatView(messages: $aiChatMessages, input: $aiInput, context: text) }
        .sheet(isPresented: $showHistory) { HistoryView(chapter: chapter, onRestore: { content in text = content }) }
        .sheet(isPresented: $showSearch) { SearchReplaceView(text: $text) }
        .alert("敏感词检测", isPresented: $showSensitiveAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            if sensitiveFound.isEmpty {
                Text("未检测到敏感词")
            } else {
                Text("检测到敏感词：\(sensitiveFound.joined(separator: "、"))")
            }
        }
    }

    private var writingSurface: some View {
        VStack(spacing: 0) {
            // 字数统计栏
            HStack {
                Text("\(text.count) 字")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("本章 +\(max(0, text.count - wordCountAtStart)) 字")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(editorBackground.opacity(0.95))

            // 编辑器
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("开始写作...")
                        .font(.system(size: store.appSettings.fontSize))
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }
                TextEditor(text: $text)
                    .font(.system(size: store.appSettings.fontSize))
                    .lineSpacing(store.appSettings.lineHeight)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .onChange(of: text) { _ in autoSave() }
            }
            .background(editorBackground)
        }
        .background(editorBackground)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var editorBackground: Color {
        switch store.appSettings.theme {
        case "古韵信笺": return Color(red: 0.96, green: 0.93, blue: 0.87)
        case "森系护眼": return Color(red: 0.93, green: 0.96, blue: 0.92)
        case "暗夜水墨": return Color(red: 0.1, green: 0.1, blue: 0.12)
        default: return Color(red: 0.97, green: 0.97, blue: 0.98)
        }
    }

    private var focusOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { toggleFocusMode() }
            VStack {
                Text("专注模式")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("点击任意处退出")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private func setupAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: store.appSettings.autoSaveInterval / 1000, repeats: true) { _ in
            autoSave()
        }
    }

    private func autoSave() {
        var c = chapter
        c.content = text
        store.updateChapter(in: bookId, c)
        chapter = c
    }

    private func saveAndRecord() {
        autoSave()
        let wordsWritten = max(0, text.count - wordCountAtStart)
        if wordsWritten > 0 {
            let duration = Date().timeIntervalSince(sessionStartTime)
            store.addRecord(WritingRecord(
                date: Date(),
                bookId: bookId,
                chapterId: chapter.id,
                wordsWritten: wordsWritten,
                duration: duration
            ))
        }
    }

    private func toggleFocusMode() {
        showFocusMode.toggle()
    }

    private func checkSensitiveWords() {
        let words = store.appSettings.sensitiveWords
        sensitiveFound = words.filter { text.contains($0) }
        showSensitiveAlert = true
    }
}

// MARK: - AI 工具面板
struct AIToolsView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let selectedText: String
    let onApply: (String) -> Void
    @State private var result = ""
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var customInstruction = ""

    var body: some View {
        NavigationStack {
            List {
                if !selectedText.isEmpty {
                    Section("已选文字（\(selectedText.count)字）") {
                        Text(selectedText)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(3)
                    }
                }

                Section("AI 操作") {
                    aiButton("润色", systemImage: "wand.and.stars", action: polish)
                    aiButton("扩写", systemImage: "text.badge.plus", action: expand)
                    aiButton("纠错", systemImage: "checkmark.shield", action: correct)
                    aiButton("续写", systemImage: "arrow.right.circle", action: continueWriting)
                }

                Section("自定义指令") {
                    TextField("输入自定义指令，如：改成古风风格", text: $customInstruction, axis: .vertical)
                        .lineLimit(2...4)
                    Button("执行") {
                        customAI()
                    }
                    .disabled(customInstruction.isEmpty || isProcessing)
                }

                if isProcessing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("AI 处理中...")
                        }
                    }
                }

                if !errorMessage.isEmpty {
                    Section("错误") {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                if !result.isEmpty {
                    Section("AI 结果") {
                        Text(result)
                            .font(.body)
                        HStack {
                            Button("替换原文") {
                                if !selectedText.isEmpty {
                                    let newText = text.replacingOccurrences(of: selectedText, with: result)
                                    onApply(newText)
                                } else {
                                    onApply(text + "\n" + result)
                                }
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("复制") {
                                UIPasteboard.general.string = result
                            }
                        }
                    }
                }
            }
            .navigationTitle("AI 工具")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func aiButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .disabled(isProcessing || !store.aiSettings.isEnabled)
    }

    private func runAI(_ operation: @escaping () async throws -> String) {
        isProcessing = true
        errorMessage = ""
        result = ""
        Task {
            do {
                let input = selectedText.isEmpty ? text : selectedText
                let output = try await operation()
                await MainActor.run {
                    result = output
                    isProcessing = false
                    store.addAILog(AICallLog(
                        scenario: "AI工具",
                        inputWords: input.count,
                        outputWords: output.count,
                        tokens: (input.count + output.count) / 2,
                        success: true
                    ))
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                    store.addAILog(AICallLog(
                        scenario: "AI工具",
                        inputWords: selectedText.count,
                        outputWords: 0,
                        tokens: 0,
                        success: false,
                        errorMessage: error.localizedDescription
                    ))
                }
            }
        }
    }

    private func polish() {
        runAI { try await AIClient.shared.polish(text: selectedText.isEmpty ? String(text.suffix(500)) : selectedText, settings: store.aiSettings) }
    }
    private func expand() {
        runAI { try await AIClient.shared.expand(text: selectedText.isEmpty ? String(text.suffix(500)) : selectedText, settings: store.aiSettings) }
    }
    private func correct() {
        runAI { try await AIClient.shared.correct(text: selectedText.isEmpty ? String(text.suffix(500)) : selectedText, settings: store.aiSettings) }
    }
    private func continueWriting() {
        runAI { try await AIClient.shared.continueWriting(context: String(text.suffix(1000)), settings: store.aiSettings) }
    }
    private func customAI() {
        let input = selectedText.isEmpty ? String(text.suffix(500)) : selectedText
        runAI {
            try await AIClient.shared.chat(messages: [
                ["role": "system", "content": "你是一个专业的网文写作助手。根据用户指令处理文字，只输出处理后的结果。"],
                ["role": "user", "content": "指令：\(customInstruction)\n\n文字：\(input)"]
            ], settings: store.aiSettings)
        }
    }
}

// MARK: - AI 对话
struct AIChatView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @Binding var messages: [AIMessage]
    @Binding var input: String
    let context: String
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { msg in
                                chatBubble(msg)
                                    .id(msg.id)
                            }
                            if isProcessing {
                                HStack {
                                    ProgressView()
                                    Text("AI 思考中...")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()
                HStack(spacing: 8) {
                    TextField("输入问题...", text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(input.isEmpty || isProcessing || !store.aiSettings.isEnabled)
                }
                .padding()
            }
            .navigationTitle("AI 对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func chatBubble(_ msg: AIMessage) -> some View {
        HStack {
            if msg.role == "user" { Spacer() }
            Text(msg.content)
                .padding(10)
                .background(msg.role == "user" ? Color.blue.opacity(0.8) : Color.gray.opacity(0.2))
                .foregroundColor(msg.role == "user" ? .white : .primary)
                .cornerRadius(12)
            if msg.role == "assistant" { Spacer() }
        }
    }

    private func sendMessage() {
        let userMsg = AIMessage(role: "user", content: input)
        messages.append(userMsg)
        let query = input
        input = ""
        isProcessing = true

        Task {
            do {
                var msgs: [[String: String]] = [
                    ["role": "system", "content": store.aiSettings.systemPrompt + "\n\n当前章节内容摘要：\(String(context.prefix(500)))"]
                ]
                for m in messages.suffix(10) {
                    msgs.append(["role": m.role, "content": m.content])
                }
                let reply = try await AIClient.shared.chat(messages: msgs, settings: store.aiSettings)
                await MainActor.run {
                    messages.append(AIMessage(role: "assistant", content: reply))
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    messages.append(AIMessage(role: "assistant", content: "出错了：\(error.localizedDescription)"))
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - 历史版本
struct HistoryView: View {
    let chapter: Chapter
    let onRestore: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if chapter.history.isEmpty {
                    Text("暂无历史版本")
                        .foregroundColor(.gray)
                } else {
                    ForEach(chapter.history.reversed()) { snap in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snap.date.formattedDateTime)
                                .font(.headline)
                            Text("\(snap.wordCount) 字")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(snap.content.prefix(100))
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(2)
                            Button("恢复此版本") {
                                onRestore(snap.content)
                                dismiss()
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("历史版本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 查找替换
struct SearchReplaceView: View {
    @Binding var text: String
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var matchCount = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("查找") {
                    TextField("输入要查找的文字", text: $searchText)
                        .onChange(of: searchText) { _ in
                            matchCount = searchText.isEmpty ? 0 : text.components(separatedBy: searchText).count - 1
                        }
                    if !searchText.isEmpty {
                        Text("找到 \(matchCount) 处匹配")
                            .foregroundColor(.gray)
                    }
                }
                Section("替换") {
                    TextField("替换为", text: $replaceText)
                    Button("全部替换") {
                        text = text.replacingOccurrences(of: searchText, with: replaceText)
                        matchCount = 0
                        searchText = ""
                    }
                    .disabled(searchText.isEmpty || matchCount == 0)
                }
            }
            .navigationTitle("查找替换")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
