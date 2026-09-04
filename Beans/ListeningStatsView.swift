import SwiftUI

// MARK: - 听歌统计页面

struct ListeningStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var report: WeeklyReport?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if isLoading {
                    ProgressView("加载统计数据...")
                } else if let report = report {
                    List {
                        Section("本周概览") {
                            HStack(spacing: 20) {
                                StatCard(title: "听歌时长", value: "\(report.totalMinutes)", unit: "分钟", icon: "clock.fill", color: .blue)
                                StatCard(title: "播放歌曲", value: "\(report.totalSongs)", unit: "首", icon: "music.note", color: .purple)
                            }
                            HStack(spacing: 20) {
                                StatCard(title: "跳过歌曲", value: "\(report.skippedCount)", unit: "首", icon: "forward.end.fill", color: .orange)
                                StatCard(title: "最活跃时段", value: "\(report.mostActiveHour)", unit: "点", icon: "sun.max.fill", color: .yellow)
                            }
                        }
                        
                        Section("最爱歌手 TOP 5") {
                            if report.topArtists.isEmpty {
                                Text("暂无数据")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(Array(report.topArtists.enumerated()), id: \.offset) { idx, artist in
                                    HStack {
                                        Text("\(idx + 1)")
                                            .font(.caption)
                                            .foregroundColor(idx < 3 ? .orange : .secondary)
                                            .frame(width: 24)
                                        Text(artist.name)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(artist.count) 次")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Section("最爱歌曲 TOP 5") {
                            if report.topSongs.isEmpty {
                                Text("暂无数据")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(Array(report.topSongs.enumerated()), id: \.offset) { idx, song in
                                    HStack {
                                        Text("\(idx + 1)")
                                            .font(.caption)
                                            .foregroundColor(idx < 3 ? .orange : .secondary)
                                            .frame(width: 24)
                                        Text(song.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(song.count) 次")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Section("总结") {
                            Text(report.summary)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    Text("暂无统计数据")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("听歌统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                report = ListeningStatsTracker.shared.weeklyReport()
                isLoading = false
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
