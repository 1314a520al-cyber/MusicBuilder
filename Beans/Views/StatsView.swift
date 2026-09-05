import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 今日概览
                HStack(spacing: 12) {
                    statCard(title: "今日字数", value: "\(store.todayWords)", icon: "pencil", color: .blue)
                    statCard(title: "AI 产出", value: "\(store.todayAIWords)", icon: "wand.and.stars", color: .purple)
                }
                HStack(spacing: 12) {
                    statCard(title: "连续天数", value: "\(store.streakDays)", icon: "flame", color: .orange)
                    statCard(title: "总字数", value: "\(store.books.reduce(0) { $0 + $1.totalWords })", icon: "text.alignleft", color: .green)
                }

                // 近7天趋势
                VStack(alignment: .leading, spacing: 8) {
                    Text("近 7 天码字趋势")
                        .font(.headline)
                    WeeklyChart(data: store.wordsForLastDays(7))
                        .frame(height: 180)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // 作品排行
                VStack(alignment: .leading, spacing: 8) {
                    Text("作品字数排行")
                        .font(.headline)
                    ForEach(Array(store.activeBooks.sorted { $0.totalWords > $1.totalWords }.prefix(5)), id: \.id) { book in
                        HStack {
                            Text(book.title)
                                .lineLimit(1)
                            Spacer()
                            Text("\(book.totalWords) 字")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)

                // AI 调用记录
                if !store.aiLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI 调用记录")
                            .font(.headline)
                        ForEach(store.aiLogs.prefix(10)) { log in
                            HStack {
                                Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(log.success ? .green : .red)
                                VStack(alignment: .leading) {
                                    Text(log.scenario)
                                        .font(.subheadline)
                                    Text("\(log.inputWords)→\(log.outputWords)字 · \(log.date, style: .time)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("码字统计")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct WeeklyChart: View {
    let data: [(date: Date, words: Int, aiWords: Int)]
    private let maxWords: Int

    init(data: [(date: Date, words: Int, aiWords: Int)]) {
        self.data = data
        self.maxWords = max(data.map { $0.words + $0.aiWords }.max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 4) {
                    Spacer()
                    VStack(spacing: 2) {
                        if item.aiWords > 0 {
                            Rectangle()
                                .fill(Color.purple.opacity(0.7))
                                .frame(height: barHeight(item.aiWords))
                        }
                        Rectangle()
                            .fill(Color.blue)
                            .frame(height: barHeight(item.words))
                    }
                    .frame(width: 24)
                    .cornerRadius(4)
                    Text(dayLabel(item.date))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(_ words: Int) -> CGFloat {
        max(CGFloat(words) / CGFloat(maxWords) * 120, 2)
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
