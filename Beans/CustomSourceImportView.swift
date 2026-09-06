import SwiftUI

// MARK: - 自定义音源导入（链接/文本/JS文件）

struct CustomSourceImportView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var importMode = 0 // 0=链接, 1=文本, 2=文件
    @State private var urlText = ""
    @State private var sourceText = ""
    @State private var showFilePicker = false
    @State private var importing = false
    @State private var importResult: String?
    @State private var parsedSources: [ThirdPartySource] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                List {
                    Section("导入方式") {
                        Picker("方式", selection: $importMode) {
                            Text("链接导入").tag(0)
                            Text("文本导入").tag(1)
                            Text("文件导入(.js)").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if importMode == 0 {
                        Section("音源链接") {
                            TextField("粘贴音源配置链接（JSON格式）", text: $urlText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .lineLimit(3...6)
                            
                            Button {
                                importFromURL()
                            } label: {
                                HStack {
                                    if importing { ProgressView() }
                                    Text("导入")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(urlText.isEmpty || importing)
                        }
                    } else if importMode == 1 {
                        Section("音源文本") {
                            TextEditor(text: $sourceText)
                                .frame(minHeight: 150)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
                            
                            Button {
                                importFromText()
                            } label: {
                                HStack {
                                    if importing { ProgressView() }
                                    Text("解析并导入")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(sourceText.isEmpty || importing)
                        }
                    } else {
                        Section("JS文件") {
                            Button {
                                showFilePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                        .foregroundColor(.blue)
                                    Text("选择 .js 音源文件")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.data, .text, .json]) { result in
                                handleFileImport(result)
                            }
                        }
                    }
                    
                    if !parsedSources.isEmpty {
                        Section("解析到 \(parsedSources.count) 个音源") {
                            ForEach(parsedSources) { src in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(src.name)
                                            .font(.subheadline)
                                        Text(src.template.prefix(50) + "...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Button {
                                saveParsedSources()
                            } label: {
                                Text("确认导入全部")
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    if let result = importResult {
                        Section {
                            Text(result)
                                .font(.subheadline)
                                .foregroundColor(result.contains("成功") ? .green : .red)
                        }
                    }
                    
                    Section("格式说明") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("JSON格式示例：")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("""
{
  "name": "我的音源",
  "template": "https://api.example.com/url?id={id}",
  "urlPath": "data.url",
  "headers": {}
}
""")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("支持 {id} {source} {quality} {name} {artist} {keyword} 占位符")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("导入音源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - 导入逻辑
    
    private func importFromURL() {
        importing = true
        importResult = nil
        parsedSources = []
        
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            importResult = "链接格式错误"
            importing = false
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let sources = parseSources(from: data) {
                    parsedSources = sources
                    importResult = "解析成功，找到 \(sources.count) 个音源"
                } else {
                    importResult = "解析失败，格式不正确"
                }
            } catch {
                importResult = "下载失败：\(error.localizedDescription)"
            }
            importing = false
        }
    }
    
    private func importFromText() {
        importing = true
        importResult = nil
        parsedSources = []
        
        if let data = sourceText.data(using: .utf8),
           let sources = parseSources(from: data) {
            parsedSources = sources
            importResult = "解析成功，找到 \(sources.count) 个音源"
        } else {
            importResult = "解析失败，请检查格式"
        }
        importing = false
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let data = try Data(contentsOf: url)
                if let sources = parseSources(from: data) {
                    parsedSources = sources
                    importResult = "文件解析成功，找到 \(sources.count) 个音源"
                } else {
                    // 尝试从JS文件中提取JSON
                    if let text = String(data: data, encoding: .utf8),
                       let jsonStart = text.range(of: "{"),
                       let jsonEnd = text.range(of: "}", options: .backwards),
                       let jsonData = String(text[jsonStart.lowerBound..<jsonEnd.upperBound]).data(using: .utf8),
                       let sources = parseSources(from: jsonData) {
                        parsedSources = sources
                        importResult = "JS文件解析成功，找到 \(sources.count) 个音源"
                    } else {
                        importResult = "文件解析失败"
                    }
                }
            } catch {
                importResult = "读取文件失败：\(error.localizedDescription)"
            }
        case .failure(let error):
            importResult = "选择文件失败：\(error.localizedDescription)"
        }
    }
    
    private func parseSources(from data: Data) -> [ThirdPartySource]? {
        // 尝试解析为单个音源
        if let single = try? JSONDecoder().decode(ThirdPartySource.self, from: data), !single.template.isEmpty {
            return [single]
        }
        // 尝试解析为数组
        if let array = try? JSONDecoder().decode([ThirdPartySource].self, from: data), !array.isEmpty {
            return array
        }
        // 尝试解析为包含 sources/data/list 字段的对象
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["sources", "data", "list", "items"] {
                if let sourcesData = dict[key] as? [[String: Any]] {
                    var sources: [ThirdPartySource] = []
                    for item in sourcesData {
                        if let name = (item["name"] as? String) ?? (item["title"] as? String),
                           let template = (item["template"] as? String) ?? (item["url"] as? String) ?? (item["api"] as? String) {
                            let source = ThirdPartySource(
                                name: name,
                                template: template,
                                urlPath: item["urlPath"] as? String ?? item["path"] as? String ?? "url",
                                headers: item["headers"] as? [String: String] ?? [:]
                            )
                            sources.append(source)
                        }
                    }
                    if !sources.isEmpty { return sources }
                }
            }
            // 单个对象格式
            if let name = (dict["name"] as? String) ?? (dict["title"] as? String),
               let template = (dict["template"] as? String) ?? (dict["url"] as? String) ?? (dict["api"] as? String) {
                return [ThirdPartySource(name: name, template: template, urlPath: dict["urlPath"] as? String ?? "url", headers: dict["headers"] as? [String: String] ?? [:])]
            }
        }
        // 纯文本URL格式（每行一个URL，或单个URL）
        if let text = String(data: data, encoding: .utf8) {
            let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0.hasPrefix("http") }
            if !lines.isEmpty {
                var sources: [ThirdPartySource] = []
                for (idx, url) in lines.enumerated() {
                    sources.append(ThirdPartySource(name: "自定义音源\(idx + 1)", template: url, urlPath: "url"))
                }
                return sources
            }
        }
        return nil
    }
    
    private func saveParsedSources() {
        for source in parsedSources {
            UnblockSourceStore.shared.addCustomSource(source)
        }
        importResult = "成功导入 \(parsedSources.count) 个音源！"
        parsedSources = []
    }
}
