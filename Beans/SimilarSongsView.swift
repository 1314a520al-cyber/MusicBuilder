import SwiftUI

// MARK: - 相似歌曲推荐页面

struct SimilarSongsView: View {
    @EnvironmentObject private var player: PlayerManager
    @StateObject private var manager = SimilarSongsManager.shared
    @Environment(\.dismiss) private var dismiss
    let sourceSong: Song
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if manager.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("正在为你推荐相似歌曲...")
                            .foregroundColor(.secondary)
                    }
                } else if manager.similarSongs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("暂无相似歌曲推荐")
                            .foregroundColor(.secondary)
                        Button("重新加载") {
                            Task { await manager.fetchSimilarSongs(for: sourceSong) }
                        }
                    }
                } else {
                    List {
                        Section("基于「\(sourceSong.name)」推荐") {
                            ForEach(Array(manager.similarSongs.enumerated()), id: \.element.identityKey) { idx, song in
                                Button {
                                    player.play(songs: manager.similarSongs, startAt: idx)
                                    dismiss()
                                } label: {
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
                                        
                                        Image(systemName: "play.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Section {
                            Button {
                                Task { await manager.startRadio(from: sourceSong) }
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "radio.fill")
                                        .foregroundColor(.purple)
                                    Text("开启智能电台（连续播放相似曲目）")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("相似歌曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                if manager.similarSongs.isEmpty {
                    await manager.fetchSimilarSongs(for: sourceSong)
                }
            }
        }
    }
}

// MARK: - 情境推荐页面

struct SceneRecommendView: View {
    @EnvironmentObject private var player: PlayerManager
    @StateObject private var manager = SimilarSongsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var songs: [Song] = []
    @State private var isLoading = false
    let scene: SimilarSongsManager.Scene
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if isLoading {
                    ProgressView("正在加载\(scene.rawValue)推荐...")
                } else {
                    List {
                        ForEach(Array(songs.enumerated()), id: \.element.identityKey) { idx, song in
                            Button {
                                player.play(songs: songs, startAt: idx)
                                dismiss()
                            } label: {
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
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("\(scene.rawValue)推荐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                isLoading = true
                songs = await manager.fetchSceneRecommendations(scene: scene)
                isLoading = false
            }
        }
    }
}
