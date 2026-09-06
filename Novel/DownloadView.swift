import SwiftUI

struct DownloadView: View {
    private var downloadManager: DownloadManager { DownloadManager.shared }
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAll = false
    
    // 按小说分组
    var groupedDownloads: [String: [DownloadedChapter]] {
        Dictionary(grouping: downloadManager.downloads, by: { $0.novelTitle })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if downloadManager.downloads.isEmpty {
                    emptyView
                } else {
                    downloadList
                }
                
                // 下载进度
                if downloadManager.isDownloading {
                    VStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView(value: downloadManager.downloadProgress)
                                .tint(.orange)
                            Text("正在下载：\(downloadManager.currentDownloadTitle)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding(.horizontal, 40)
                        Spacer()
                    }
                }
            }
            .navigationTitle("下载管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
                if !downloadManager.downloads.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("全部删除") {
                            showDeleteAll = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .alert("删除所有下载", isPresented: $showDeleteAll) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    downloadManager.clearAllDownloads()
                }
            } message: {
                Text("确定要删除所有已下载的小说吗？")
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("暂无下载")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("在阅读页面点击下载按钮开始下载")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var downloadList: some View {
        List {
            ForEach(groupedDownloads.keys.sorted(), id: \.self) { novelTitle in
                let chapters = groupedDownloads[novelTitle] ?? []
                Section {
                    ForEach(chapters) { download in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(download.chapterTitle)
                                    .font(.system(size: 15))
                                    .lineLimit(1)
                                HStack(spacing: 8) {
                                    Text(download.folderPath)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Text(downloadManager.formatSize(download.fileSize))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                downloadManager.deleteDownload(download)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack {
                        Text(novelTitle)
                            .font(.headline)
                        Spacer()
                        Text("\(chapters.count) 章")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                HStack {
                    Text("总计")
                    Spacer()
                    Text("\(downloadManager.downloads.count) 章 · \(downloadManager.formatSize(downloadManager.totalDownloadSize()))")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
