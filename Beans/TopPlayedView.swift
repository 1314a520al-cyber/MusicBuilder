import SwiftUI

// MARK: - 听歌排行（播放次数最多的歌曲）

struct TopPlayedView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                ScrollView {
                    if player.topPlayed.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("还没有听歌记录")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            Text("多听几首歌，这里会显示你最爱的歌曲")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(player.topPlayed.enumerated()), id: \.element.song.identityKey) { index, item in
                                Button {
                                    player.playSong(item.song, in: player.topPlayed.map { $0.song })
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        // 排名
                                        ZStack {
                                            if index < 3 {
                                                Circle()
                                                    .fill(LinearGradient(
                                                        colors: index == 0 ? [.yellow, .orange] : (index == 1 ? [.gray, .gray.opacity(0.6)] : [.orange.opacity(0.7), .brown]),
                                                        startPoint: .top, endPoint: .bottom))
                                                    .frame(width: 28, height: 28)
                                                Text("\(index + 1)")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(.white)
                                            } else {
                                                Text("\(index + 1)")
                                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 28)
                                            }
                                        }
                                        // 封面
                                        AsyncImage(url: item.song.coverURL) { phase in
                                            if case .success(let img) = phase {
                                                img.resizable().scaledToFill()
                                            } else {
                                                Rectangle().fill(Color.primary.opacity(0.1))
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        // 信息
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.song.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(Color.beansLabel)
                                                .lineLimit(1)
                                            Text(item.song.artists)
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.beansComment)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        // 播放次数
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(item.count)")
                                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                                .foregroundStyle(theme.accent.highlight)
                                            Text("次")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if index < player.topPlayed.count - 1 {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("听歌排行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
