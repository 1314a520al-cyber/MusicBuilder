import SwiftUI

// MARK: - 年度听歌报告

struct AnnualReportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var totalMinutes = 0
    @State private var totalSongs = 0
    @State private var topArtists: [(name: String, count: Int)] = []
    @State private var topSongs: [(name: String, count: Int)] = []
    @State private var mostActiveHour = 20
    @State private var favoriteDay = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.15, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.15, blue: 0.4), Color(red: 0.1, green: 0.2, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 标题
                        VStack(spacing: 8) {
                            Text("2026")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                            Text("年度听歌报告")
                                .font(.title2.bold())
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)
                        
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.top, 60)
                        } else {
                            // 总时长
                            ReportCard(icon: "clock.fill", title: "年度听歌时长", value: "\(totalMinutes)", unit: "分钟", color: .orange)
                            
                            // 播放歌曲数
                            ReportCard(icon: "music.note", title: "播放歌曲", value: "\(totalSongs)", unit: "首", color: .pink)
                            
                            // 最爱歌手
                            VStack(alignment: .leading, spacing: 12) {
                                Label("最爱歌手 TOP 5", systemImage: "person.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                ForEach(Array(topArtists.enumerated()), id: \.offset) { idx, artist in
                                    HStack {
                                        Text("\(idx + 1)")
                                            .font(.caption.bold())
                                            .foregroundColor(idx < 3 ? .yellow : .white.opacity(0.6))
                                            .frame(width: 24)
                                        Text(artist.name)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(artist.count) 次")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            
                            // 最爱歌曲
                            VStack(alignment: .leading, spacing: 12) {
                                Label("单曲循环 TOP 5", systemImage: "repeat")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                ForEach(Array(topSongs.enumerated()), id: \.offset) { idx, song in
                                    HStack {
                                        Text("\(idx + 1)")
                                            .font(.caption.bold())
                                            .foregroundColor(idx < 3 ? .yellow : .white.opacity(0.6))
                                            .frame(width: 24)
                                        Text(song.name)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(song.count) 次")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            
                            // 最活跃时段
                            ReportCard(icon: "sun.max.fill", title: "最活跃时段", value: "\(mostActiveHour):00", unit: "", color: .yellow)
                            
                            Text("音乐陪伴了你一整年，感谢有你")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.bottom, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("年度报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        // 统计全年数据
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        var totalSec = 0
        var totalCount = 0
        var artistAgg: [String: Int] = [:]
        var songAgg: [String: Int] = [:]
        var hourAgg: [Int: Int] = [:]
        var weekdayAgg: [Int: Int] = [:]
        
        for day in 0..<365 {
            if let date = calendar.date(byAdding: .day, value: -day, to: Date()),
               calendar.component(.year, from: date) == year {
                let key = dateKey(date)
                if let data = UserDefaults.standard.data(forKey: "beans.listeningStats_\(key)"),
                   let stats = try? JSONDecoder().decode(ListeningStatsTracker.DailyStats.self, from: data) {
                    totalSec += stats.totalSeconds
                    totalCount += stats.playCount
                    for (k, v) in stats.artistCounts { artistAgg[k, default: 0] += v }
                    for (k, v) in stats.songCounts { songAgg[k, default: 0] += v }
                    for (k, v) in stats.hourCounts { hourAgg[k, default: 0] += v }
                    weekdayAgg[calendar.component(.weekday, from: date), default: 0] += stats.playCount
                }
            }
        }
        
        totalMinutes = totalSec / 60
        totalSongs = totalCount
        topArtists = Array(artistAgg.sorted { $0.value > $1.value }.prefix(5)).map { (name: $0.key, count: $0.value) }
        topSongs = Array(songAgg.sorted { $0.value > $1.value }.prefix(5)).map { (name: $0.key, count: $0.value) }
        mostActiveHour = hourAgg.sorted { $0.value > $1.value }.first?.key ?? 20
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        favoriteDay = weekdays[weekdayAgg.sorted { $0.value > $1.value }.first?.key ?? 1]
        isLoading = false
    }
    
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct ReportCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 50, height: 50)
                .background(color.opacity(0.2))
                .cornerRadius(12)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title.bold())
                        .foregroundColor(.white)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
}
