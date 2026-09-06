import SwiftUI

struct DownloadFolderSelectView: View {
    let novel: Novel
    let chapters: [NovelChapter]
    private var downloadManager: DownloadManager { DownloadManager.shared }
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFolder = "默认"
    @State private var newFolderName = ""
    @State private var showNewFolder = false
    @State private var downloadAll = true
    @State private var startChapter = 0
    @State private var endChapter = 0
    
    var folders: [String] {
        var list = downloadManager.getFolders()
        if !list.contains("默认") {
            list.insert("默认", at: 0)
        }
        return list
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("下载范围") {
                    Picker("下载范围", selection: $downloadAll) {
                        Text("整本下载").tag(true)
                        Text("选择章节").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    if !downloadAll {
                        Stepper("从第 \(startChapter + 1) 章开始", value: $startChapter, in: 0...max(0, chapters.count - 1))
                        Stepper("到第 \(endChapter + 1) 章结束", value: $endChapter, in: startChapter...max(startChapter, chapters.count - 1))
                    }
                }
                
                Section("保存位置") {
                    Picker("选择文件夹", selection: $selectedFolder) {
                        ForEach(folders, id: \.self) { folder in
                            HStack {
                                Image(systemName: "folder.fill")
                                Text(folder)
                            }
                            .tag(folder)
                        }
                    }
                    
                    if showNewFolder {
                        HStack {
                            TextField("新文件夹名称", text: $newFolderName)
                            Button("创建") {
                                if !newFolderName.isEmpty {
                                    downloadManager.createFolder(newFolderName)
                                    selectedFolder = newFolderName
                                    newFolderName = ""
                                    showNewFolder = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Button {
                            showNewFolder = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("新建文件夹")
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
                
                Section {
                    Button {
                        startDownload()
                    } label: {
                        HStack {
                            Spacer()
                            if downloadManager.isDownloading {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("开始下载")
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                    .disabled(downloadManager.isDownloading)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("下载小说")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                endChapter = max(0, chapters.count - 1)
            }
        }
    }
    
    private func startDownload() {
        let range = downloadAll ? Array(0..<chapters.count) : Array(startChapter...endChapter)
        
        Task {
            for index in range {
                let chapter = chapters[index]
                do {
                    let content = try await NovelAPI.shared.getChapterContent(url: chapter.url)
                    downloadManager.downloadChapter(novel: novel, chapter: chapter, content: content.content, folder: selectedFolder)
                    // 等待下载完成
                    while downloadManager.isDownloading {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                } catch {
                    // 跳过失败的章节
                }
            }
            await MainActor.run {
                dismiss()
            }
        }
    }
}
