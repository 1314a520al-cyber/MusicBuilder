import SwiftUI

// MARK: - 播放队列管理页面

struct QueueManagementView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if player.queue.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("播放队列为空")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section("当前播放") {
                            if let current = player.currentSong {
                                HStack(spacing: 12) {
                                    AsyncImage(url: current.coverURL) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.2))
                                    }
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(8)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(current.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(current.artists)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        Section("接下来播放 (\(upcomingSongs.count) 首)") {
                            ForEach(upcomingSongs.indices, id: \.self) { idx in
                                let song = upcomingSongs[idx]
                                HStack(spacing: 12) {
                                    Text("\(idx + 1)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 24)
                                    
                                    AsyncImage(url: song.coverURL) { img in
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.2))
                                    }
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(6)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(song.artists)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    if editMode == .inactive {
                                        Button {
                                            player.playQueueIndex(absoluteIndex(forUpcoming: idx))
                                            dismiss()
                                        } label: {
                                            Image(systemName: "play.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                for idx in indexSet {
                                    player.removeFromQueue(at: absoluteIndex(forUpcoming: idx))
                                }
                            }
                            .onMove { source, destination in
                                player.moveQueueItem(from: source, to: absoluteIndex(forUpcoming: destination))
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .environment(\.editMode, $editMode)
                }
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !player.queue.isEmpty {
                        Button(editMode == .inactive ? "编辑" : "完成") {
                            withAnimation {
                                editMode = editMode == .inactive ? .active : .inactive
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !player.queue.isEmpty {
                        Button("清空") {
                            player.clearQueueExceptCurrent()
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    private var upcomingSongs: [Song] {
        let startIdx = player.currentIndex + 1
        guard startIdx < player.queue.count else { return [] }
        return Array(player.queue[startIdx...])
    }
    
    private func absoluteIndex(forUpcoming upcomingIndex: Int) -> Int {
        player.currentIndex + 1 + upcomingIndex
    }
}
