import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @State private var showBackup = false
    @State private var backupURL: URL?
    @State private var showActivity = false
    @State private var showClearCacheAlert = false
    @State private var showResetAlert = false
    @State private var refreshID = UUID()

    var body: some View {
        Form {
            Section("AI 设置") {
                NavigationLink(destination: AIConfigView()) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.purple)
                        Text("AI 模型配置")
                        Spacer()
                        Text(store.aiSettings.isEnabled ? "已配置" : "未配置")
                            .foregroundColor(.gray)
                    }
                }
            }

            Section("主题") {
                Picker("主题", selection: Binding(
                    get: { store.appSettings.theme },
                    set: { store.appSettings.theme = $0; store.save() }
                )) {
                    ForEach(["无界通透", "古韵信笺", "森系护眼", "暗夜水墨"], id: \.self) { theme in
                        Text(theme).tag(theme)
                    }
                }
            }

            Section("编辑器") {
                Stepper("字号：\(Int(store.appSettings.fontSize))", value: Binding(
                    get: { store.appSettings.fontSize },
                    set: { store.appSettings.fontSize = $0; store.save() }
                ), in: 12...28, step: 1)

                VStack(alignment: .leading) {
                    Text("行高：\(String(format: "%.1f", store.appSettings.lineHeight))")
                    Slider(value: Binding(
                        get: { store.appSettings.lineHeight },
                        set: { store.appSettings.lineHeight = $0; store.save() }
                    ), in: 1.0...3.0, step: 0.1)
                }

                Toggle("显示字数统计", isOn: Binding(
                    get: { store.appSettings.showWordCount },
                    set: { store.appSettings.showWordCount = $0; store.save() }
                ))
            }

            Section("打字体验") {
                Picker("打字音效", selection: Binding(
                    get: { store.appSettings.typingSound },
                    set: { store.appSettings.typingSound = $0; store.save() }
                )) {
                    ForEach(["静音", "青轴机械键", "茶轴机械键", "老式打字机", "枪声", "狗狗汪叫"], id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                Picker("光标特效", selection: Binding(
                    get: { store.appSettings.typingEffect },
                    set: { store.appSettings.typingEffect = $0; store.save() }
                )) {
                    ForEach(["无", "挥毫泼墨", "墨纹涟漪", "云烟缭绕", "真实烈焰", "文字鼓励"], id: \.self) { effect in
                        Text(effect).tag(effect)
                    }
                }
            }

            Section("写作目标") {
                Stepper("每日目标：\(store.appSettings.dailyTarget) 字", value: Binding(
                    get: { store.appSettings.dailyTarget },
                    set: { store.appSettings.dailyTarget = $0; store.save() }
                ), in: 500...20000, step: 500)
            }

            Section("敏感词") {
                NavigationLink(destination: SensitiveWordsView()) {
                    Text("敏感词库管理")
                }
            }

            Section("存储占用") {
                let size = store.storageSize()
                HStack {
                    Text("作品数据")
                    Spacer()
                    Text(store.formatSize(size.data))
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("缓存文件")
                    Spacer()
                    Text(store.formatSize(size.cache))
                        .foregroundColor(.gray)
                }
                HStack {
                    Text("总占用")
                    Spacer()
                    Text(store.formatSize(size.total))
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }

            Section("数据管理") {
                Button(action: {
                    if let url = store.backupAll() {
                        backupURL = url
                        showActivity = true
                    }
                }) {
                    Label("备份全部数据", systemImage: "archivebox")
                }
                Button(action: { showBackup = true }) {
                    Label("从备份恢复", systemImage: "arrow.uturn.backward")
                }
                Button(role: .destructive, action: {
                    showClearCacheAlert = true
                }) {
                    Label("清除缓存", systemImage: "paintbrush")
                }
                Button(role: .destructive, action: {
                    showResetAlert = true
                }) {
                    Label("删除全部数据", systemImage: "trash")
                }
            }

            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("3.0.2")
                        .foregroundColor(.gray)
                }
                Text("易创 - 纯本地网文写作助手")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showActivity) {
            if let url = backupURL {
                ActivityView(activityItems: [url])
            }
        }
        .fileImporter(isPresented: $showBackup, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                restoreBackup(from: url)
                refreshID = UUID()
            }
        }
        .alert("清除缓存", isPresented: $showClearCacheAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                store.clearCache()
                refreshID = UUID()
            }
        } message: {
            Text("将清除所有临时缓存文件，不会影响作品数据。")
        }
        .alert("删除全部数据", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("全部删除", role: .destructive) {
                store.resetAllData()
                refreshID = UUID()
            }
        } message: {
            Text("此操作将删除所有作品、章节、码字记录、灵感和设置，且无法恢复。建议先备份数据。")
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshID)
    }

    private func restoreBackup(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let booksData = try? JSONSerialization.data(withJSONObject: dict?["books"] ?? []),
               let books = try? decoder.decode([Book].self, from: booksData) {
                store.books = books
            }
            if let recordsData = try? JSONSerialization.data(withJSONObject: dict?["records"] ?? []),
               let records = try? decoder.decode([WritingRecord].self, from: recordsData) {
                store.records = records
            }
            if let inspData = try? JSONSerialization.data(withJSONObject: dict?["inspirations"] ?? []),
               let inspirations = try? decoder.decode([Inspiration].self, from: inspData) {
                store.inspirations = inspirations
            }
            store.save()
        } catch {
            print("恢复失败: \(error)")
        }
    }
}

struct SensitiveWordsView: View {
    @EnvironmentObject var store: DataStore
    @State private var newWord = ""

    var body: some View {
        Form {
            Section("添加敏感词") {
                HStack {
                    TextField("输入敏感词", text: $newWord)
                    Button("添加") {
                        if !newWord.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.appSettings.sensitiveWords.append(newWord.trimmingCharacters(in: .whitespaces))
                            store.save()
                            newWord = ""
                        }
                    }
                    .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("敏感词列表") {
                if store.appSettings.sensitiveWords.isEmpty {
                    Text("暂无敏感词")
                        .foregroundColor(.gray)
                } else {
                    ForEach(store.appSettings.sensitiveWords, id: \.self) { word in
                        Text(word)
                    }
                    .onDelete { indexSet in
                        store.appSettings.sensitiveWords.remove(atOffsets: indexSet)
                        store.save()
                    }
                }
            }
        }
        .navigationTitle("敏感词库")
        .navigationBarTitleDisplayMode(.inline)
    }
}
