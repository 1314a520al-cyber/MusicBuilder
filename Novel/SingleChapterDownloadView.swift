import SwiftUI

struct SingleChapterDownloadView: View {
    let novel: Novel
    let chapter: NovelChapter
    let content: String
    private var downloadManager: DownloadManager { DownloadManager.shared }
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFolder = "默认"
    @State private var newFolderName = ""
    @State private var showNewFolder = false
    
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
                Section("章节信息") {
                    Text(novel.title)
                        .font(.headline)
                    Text(chapter.title)
                        .foregroundStyle(.secondary)
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
                        downloadManager.downloadChapter(novel: novel, chapter: chapter, content: content, folder: selectedFolder)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                            Text("下载本章")
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("下载章节")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
