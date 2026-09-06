import SwiftUI

// MARK: - 下载管理页面

struct DownloadManagementView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 分段选择
                    Picker("下载状态", selection: $selectedTab) {
                        Text("已下载").tag(0)
                        Text("下载中").tag(1)
                        Text("已失败").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    if selectedTab == 0 {
                        downloadedList
                    } else if selectedTab == 1 {
                        downloadingList
                    } else {
                        failedList
                    }
                }
            }
            .navigationTitle("下载管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    private var downloadedList: some View {
        List {
            if DownloadManager.shared.downloadedSongs.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("暂无已下载歌曲")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("已下载 (\(DownloadManager.shared.downloadedSongs.count) 首)") {
                    ForEach(DownloadManager.shared.downloadedSongs, id: \.identityKey) { song in
                        HStack(spacing: 12) {
                            AsyncImage(url: song.coverURL) { img in
                                img.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 44, height: 44)
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(song.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(song.artists)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button {
                                player.play(songs: DownloadManager.shared.downloadedSongs, startAt: DownloadManager.shared.downloadedSongs.firstIndex(where: { $0.identityKey == song.identityKey }) ?? 0)
                                dismiss()
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                DownloadManager.shared.delete(song: song)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var downloadingList: some View {
        List {
            if DownloadManager.shared.activeDownloads.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("暂无下载任务")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("下载中") {
                    ForEach(Array(DownloadManager.shared.activeDownloads.keys), id: \.self) { key in
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(key)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var failedList: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("暂无失败任务")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }
}
