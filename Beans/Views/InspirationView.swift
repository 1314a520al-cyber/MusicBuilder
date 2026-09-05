import SwiftUI

struct InspirationView: View {
    @EnvironmentObject var store: DataStore
    @State private var newIdea = ""
    @State private var selectedTag = "全部"
    @State private var showAIInspiration = false

    private let tags = ["全部", "剧情", "人物", "设定", "对话", "其他"]

    private var filtered: [Inspiration] {
        if selectedTag == "全部" { return store.inspirations }
        return store.inspirations.filter { $0.tag == selectedTag }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 快速输入
            HStack(spacing: 8) {
                TextField("记录灵感...", text: $newIdea, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                Button(action: addIdea) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(newIdea.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            // 标签筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button(action: { selectedTag = tag }) {
                            Text(tag)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedTag == tag ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedTag == tag ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                    Button(action: { showAIInspiration = true }) {
                        Label("AI 灵感", systemImage: "wand.and.stars")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)

            // 灵感列表
            List {
                if filtered.isEmpty {
                    Text("还没有灵感记录")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filtered) { idea in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                if idea.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                Text(idea.content)
                                    .font(.body)
                                Spacer()
                            }
                            HStack {
                                if !idea.tag.isEmpty {
                                    Text(idea.tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                Text(idea.createdAt.formattedDateTime)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button(action: { store.togglePinInspiration(idea.id) }) {
                                Label(idea.isPinned ? "取消置顶" : "置顶", systemImage: idea.isPinned ? "pin.slash" : "pin")
                            }
                            Button(action: {
                                UIPasteboard.general.string = idea.content
                            }) {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive, action: { store.deleteInspiration(idea.id) }) {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            store.deleteInspiration(filtered[idx].id)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("灵感速记")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAIInspiration) {
            AIInspirationView { idea in
                store.addInspiration(idea, tag: "AI")
                showAIInspiration = false
            }
        }
    }

    private func addIdea() {
        let trimmed = newIdea.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.addInspiration(trimmed, tag: selectedTag == "全部" ? "" : selectedTag)
            newIdea = ""
        }
    }
}

struct AIInspirationView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void
    @State private var topic = ""
    @State private var result = ""
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("灵感主题") {
                    TextField("如：仙侠小说的反派设定", text: $topic)
                    Button("生成灵感") {
                        generate()
                    }
                    .disabled(topic.isEmpty || isProcessing || !store.aiSettings.isEnabled)
                }
                if isProcessing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("AI 生成中...")
                        }
                    }
                }
                if !result.isEmpty {
                    Section("AI 灵感") {
                        Text(result)
                        HStack {
                            Button("保存") {
                                onSave(result)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("重新生成") { generate() }
                        }
                    }
                }
            }
            .navigationTitle("AI 灵感")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func generate() {
        isProcessing = true
        result = ""
        Task {
            do {
                let r = try await AIClient.shared.chat(messages: [
                    ["role": "system", "content": "你是一个创意灵感生成器。根据用户给出的主题，生成3-5个具体、有创意的灵感点子，每个点子用简短的文字描述。"],
                    ["role": "user", "content": "主题：\(topic)"]
                ], settings: store.aiSettings)
                await MainActor.run {
                    result = r
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    result = "生成失败：\(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}
