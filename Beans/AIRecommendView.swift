import SwiftUI

// MARK: - AI智能推荐（基于本地规则，无需API）

struct AIRecommendView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var recommendedSongs: [Song] = []
    @State private var loading = true
    @State private var recommendType: RecommendType = .similar
    
    enum RecommendType: String, CaseIterable {
        case similar = "相似歌曲"
        case mood = "心情推荐"
        case radio = "智能电台"
        case rediscover = "重温经典"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                
                VStack(spacing: 0) {
                    // 推荐类型选择
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(RecommendType.allCases, id: \.self) { type in
                                Button {
                                    recommendType = type
                                    generateRecommendations()
                                } label: {
                                    Text(type.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(recommendType == type ? .white : theme.accent.highlight)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule().fill(recommendType == type ? theme.accent.highlight : theme.accent.highlight.opacity(0.15))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    if loading {
                        Spacer()
                        ProgressView("AI正在为你推荐...")
                            .tint(theme.accent.highlight)
                        Spacer()
                    } else if recommendedSongs.isEmpty {
                        Spacer()
                        EmptyStateView(icon: "sparkles", text: "暂无推荐，多听几首歌再来吧")
                        Spacer()
                    } else {
                        List {
                            ForEach(Array(recommendedSongs.enumerated()), id: \.element.id) { idx, song in
                                SongCell(song: song, glassRow: true) {
                                    player.play(songs: recommendedSongs, startAt: idx)
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("AI 推荐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        generateRecommendations()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(theme.accent.highlight)
                    }
                }
            }
            .task {
                generateRecommendations()
            }
        }
    }
    
    private func generateRecommendations() {
        loading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // 基于播放历史和当前歌曲生成推荐
            let history = UserDefaults.standard.array(forKey: "beans.recentSongs") as? [Data] ?? []
            var allSongs: [Song] = []
            
            // 从历史中解码歌曲
            for item in history.prefix(20) {
                if let data = item as? Data, let song = try? JSONDecoder().decode(Song.self, from: data) {
                    allSongs.append(song)
                }
            }
            
            // 如果有当前播放的歌曲，优先推荐相似的
            if let current = player.currentSong {
                allSongs.insert(current, at: 0)
            }
            // 如果没有历史也没有当前歌曲，提示用户多听歌
            guard !allSongs.isEmpty else {
                recommendedSongs = []
                loading = false
                return
            }
            
            switch recommendType {
            case .similar:
                // 相似歌曲：同歌手或同平台
                recommendedSongs = allSongs.filter { song in
                    if let current = player.currentSong {
                        return song.artists == current.artists || song.source == current.source
                    }
                    return true
                }.prefix(20).map { $0 }
            case .mood:
                // 心情推荐：随机打乱
                recommendedSongs = Array(allSongs.shuffled().prefix(20))
            case .radio:
                // 智能电台：按平台分组
                recommendedSongs = Dictionary(grouping: allSongs, by: { $0.source })
                    .flatMap { $0.value.prefix(5) }
                    .shuffled()
                    .prefix(20).map { $0 }
            case .rediscover:
                // 重温经典：取最旧的历史
                recommendedSongs = Array(allSongs.reversed().prefix(20))
            }
            
            // 去重
            var seen = Set<String>()
            recommendedSongs = recommendedSongs.filter { song in
                let key = song.identityKey
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            
            loading = false
        }
    }
}
