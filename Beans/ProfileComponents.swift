import SwiftUI

// MARK: - 听歌统计 + 等级卡片

struct ListeningStatsCard: View {
    @ObservedObject private var stats = ListeningStatsStore.shared
    @EnvironmentObject private var theme: ThemeStore

    var body: some View {
        let _ = theme.accent
        VStack(alignment: .leading, spacing: 12) {
            // 等级 + 经验条
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [theme.accent.highlight, theme.accent.highlight.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    VStack(spacing: 0) {
                        Text("Lv")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("\(stats.level)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stats.levelTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                        Text("还需 \(stats.expToNext) 经验升级")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.beansComment)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(colors: [theme.accent.highlight, theme.accent.highlight.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(stats.expProgress))
                        }
                    }
                    .frame(height: 6)
                }
            }

            // 统计数据
            HStack(spacing: 0) {
                statItem(title: "今日听歌", value: stats.todayTimeText, icon: "clock.fill")
                statItem(title: "本周听歌", value: stats.weekTimeText, icon: "calendar")
                statItem(title: "累计听歌", value: stats.totalTimeText, icon: "infinity")
                statItem(title: "播放首数", value: "\(stats.totalSongs)", icon: "music.note")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.accent.highlight.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.accent.highlight.opacity(0.2), lineWidth: 1)
        )
    }

    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(theme.accent.highlight)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.beansLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Color.beansComment)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 缓存管理页面（分类占比 / 上限 / 可折叠）

struct CacheManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    @State private var categories: [CacheCategory] = []
    @State private var totalSize: Int64 = 0
    @State private var expanded = true
    @State private var limitMB: Int = CacheManager.limitMB
    @State private var clearing = false

    private let limitOptions = [100, 200, 500, 1000, 2000, 5000]

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 总缓存卡片
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("缓存总量")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text(CacheManager.formatted(totalSize))
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundStyle(theme.accent.highlight)
                            }
                            Spacer()
                            if CacheManager.limitExceeded {
                                Label("已超出上限", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(.orange.opacity(0.15)))
                            }
                        }
                        // 上限进度条
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("上限 \(limitMB) MB")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(Double(totalSize) / 1024 / 1024)) MB")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(CacheManager.limitExceeded ? .orange : .secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.08))
                                    Capsule()
                                        .fill(CacheManager.limitExceeded ? Color.orange : theme.accent.highlight)
                                        .frame(width: min(geo.size.width * CGFloat(Double(totalSize) / Double(limitMB * 1024 * 1024)), geo.size.width))
                                }
                            }
                            .frame(height: 8)
                        }
                        // 上限选择
                        HStack {
                            Text("缓存上限")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("上限", selection: $limitMB) {
                                ForEach(limitOptions, id: \.self) { mb in
                                    Text(mb >= 1000 ? "\(mb/1000) GB" : "\(mb) MB").tag(mb)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: limitMB) { newValue in
                                CacheManager.limitMB = newValue
                            }
                        }
                        // 清理按钮
                        Button {
                            clearing = true
                            CacheManager.clearAll()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                reload()
                                clearing = false
                            }
                        } label: {
                            HStack {
                                Image(systemName: clearing ? "hourglass" : "trash.fill")
                                Text(clearing ? "清理中..." : "一键清理全部缓存")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(theme.accent.highlight))
                        }
                        .buttonStyle(.plain)
                        .disabled(clearing)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.05)))

                    // 分类占比（可折叠）
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expanded.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2.fill")
                                    .foregroundStyle(theme.accent.highlight)
                                Text("缓存分类占比")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .rotationEffect(.degrees(expanded ? 0 : -90))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if expanded {
                            VStack(spacing: 0) {
                                ForEach(categories) { cat in
                                    if cat.size > 0 || cat.name == "已下载歌曲" {
                                        CacheCategoryRow(category: cat, total: totalSize) {
                                            CacheManager.clearCategory(cat.name)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { reload() }
                                        }
                                        Divider().padding(.leading, 56)
                                    }
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.primary.opacity(0.05)))

                    Text("已下载的歌曲不会被自动清理，可在下载管理中手动删除。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .navigationTitle("缓存管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear { reload() }
        }
    }

    private func reload() {
        categories = CacheManager.categories()
        totalSize = CacheManager.totalSize()
    }
}

private struct CacheCategoryRow: View {
    let category: CacheCategory
    let total: Int64
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(category.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.beansLabel)
                // 占比条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.06))
                        Capsule()
                            .fill(category.color.opacity(0.7))
                            .frame(width: max(2, geo.size.width * CGFloat(Double(category.size) / Double(max(total, 1)))))
                    }
                }
                .frame(height: 4)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(CacheManager.formatted(category.size))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.beansLabel)
                if category.name != "已下载歌曲" && category.size > 0 {
                    Button("清理", action: onClear)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
