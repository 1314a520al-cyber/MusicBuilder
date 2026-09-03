import SwiftUI

/// 更新日志页面
struct UpdateLogView: View {
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var store = UpdateStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(store.entries) { entry in
                            updateCard(entry)
                        }
                    }
                    .padding(16)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func updateCard(_ entry: UpdateEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("v\(entry.version)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.accent.highlight)
                Spacer()
                Text(entry.date)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beansComment)
            }
            if !entry.features.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("新功能", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                    ForEach(entry.features, id: \.self) { f in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.green.opacity(0.7))
                            Text(f)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.beansLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if !entry.fixes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("修复与优化", systemImage: "wrench.and.screwdriver")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    ForEach(entry.fixes, id: \.self) { f in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange.opacity(0.7))
                            Text(f)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.beansLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

/// 启动时更新提示弹窗（三个按钮：下载/稍后/取消）
struct UpdatePromptView: View {
    @EnvironmentObject private var theme: ThemeStore
    let entry: UpdateEntry
    var onDownload: () -> Void
    var onLater: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 0) {
                // 顶部渐变头
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [theme.accent.highlight, theme.accent.highlight.opacity(0.5), Color.purple.opacity(0.3)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                            Text("发现新版本")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        Text("v\(entry.version) · \(entry.date)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity)

                // 内容滚动区
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if !entry.features.isEmpty {
                            sectionView(title: "新功能", icon: "sparkles", color: .green, items: entry.features)
                        }
                        if !entry.fixes.isEmpty {
                            sectionView(title: "修复", icon: "wrench.and.screwdriver", color: .orange, items: entry.fixes)
                        }
                        if !entry.deletions.isEmpty {
                            sectionView(title: "移除", icon: "trash", color: .red, items: entry.deletions)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .frame(maxHeight: 150)

                // 三按钮
                HStack(spacing: 10) {
                    Button { onDownload() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("下载")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(LinearGradient(colors: [theme.accent.highlight, theme.accent.highlight.opacity(0.7)], startPoint: .leading, endPoint: .trailing)))
                    }
                    .buttonStyle(.plain)

                    Button { onLater() } label: {
                        Text("稍后")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.beansLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.primary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    Button { onCancel() } label: {
                        Text("取消")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .padding(.top, 6)
            }
            .frame(width: 280)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.systemBackground)))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 12)
        }
    }

    private func sectionView(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
            }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(color.opacity(0.6))
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)
                    Text(item)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.beansLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
