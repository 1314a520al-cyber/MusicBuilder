import SwiftUI
import UniformTypeIdentifiers

struct SourceManagerView: View {
    @ObservedObject private var sourceManager = NovelSourceManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSource = false
    @State private var showImportText = false
    @State private var showFilePicker = false
    @State private var newName = ""
    @State private var newURL = ""
    @State private var importText = ""
    @State private var importResult = ""
    @State private var showResult = false
    
    var body: some View {
        NavigationStack {
            List {
                if sourceManager.sources.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "book")
                            .font(.system(size: 40))
                            .foregroundStyle(.gray)
                        Text("暂无书源")
                            .font(.headline)
                        Text("点击右上角 + 添加或导入书源")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 60)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(sourceManager.sources) { source in
                        SourceRow(source: source, manager: sourceManager)
                    }
                }
            }
            .navigationTitle("小说源管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddSource = true
                        } label: {
                            Label("手动添加", systemImage: "plus")
                        }
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("从文件导入", systemImage: "folder")
                        }
                        Button {
                            showImportText = true
                        } label: {
                            Label("粘贴JSON导入", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        // fileImporter放在NavigationStack外面，确保能正常弹出
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.json, .text, .plainText, .data, .content]) { result in
            handleFileImport(result: result)
        }
        .alert("添加小说源", isPresented: $showAddSource) {
            TextField("源名称（如：笔趣阁）", text: $newName)
            TextField("网站地址（如：https://www.example.com）", text: $newURL)
            Button("取消", role: .cancel) {
                newName = ""; newURL = ""
            }
            Button("添加") {
                if !newName.isEmpty && !newURL.isEmpty {
                    sourceManager.addSource(name: newName, baseURL: newURL)
                    newName = ""; newURL = ""
                }
            }
        } message: {
            Text("只需填写名称和网站地址，系统会自动识别搜索和阅读功能")
        }
        .alert("粘贴JSON导入", isPresented: $showImportText) {
            TextField("JSON格式书源", text: $importText, axis: .vertical)
                .frame(minHeight: 100)
            Button("取消", role: .cancel) {
                importText = ""
            }
            Button("导入") {
                let count = sourceManager.importFromJSON(importText)
                importResult = count > 0 ? "成功导入 \(count) 个书源" : "导入失败，请检查JSON格式是否正确"
                importText = ""
                showResult = true
            }
        } message: {
            Text("格式示例：[{\"name\":\"源名\",\"baseURL\":\"https://www.example.com\"}]")
        }
        .alert("导入结果", isPresented: $showResult) {
            Button("确定") {
                showResult = false
                importResult = ""
            }
        } message: {
            Text(importResult)
        }
    }
    
    private func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                var text = String(data: data, encoding: .utf8)
                if text == nil {
                    let gbkEnc = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
                    text = String(data: data, encoding: String.Encoding(rawValue: gbkEnc))
                }
                if let jsonText = text, !jsonText.isEmpty {
                    let count = sourceManager.importFromJSON(jsonText)
                    importResult = count > 0 ? "成功导入 \(count) 个书源" : "导入失败：文件内容格式不正确，请确保是有效的JSON格式"
                } else {
                    importResult = "导入失败：无法读取文件内容"
                }
            } catch {
                importResult = "导入失败：\(error.localizedDescription)"
            }
            showResult = true
        case .failure(let error):
            importResult = "文件选择失败：\(error.localizedDescription)"
            showResult = true
        }
    }
}

struct SourceRow: View {
    let source: NovelSource
    let manager: NovelSourceManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.system(size: 16, weight: .medium))
                Text(source.baseURL)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { manager.enabledSourceIds.contains(source.id) },
                set: { _ in manager.toggleSource(source.id) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                manager.removeSource(source.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}
