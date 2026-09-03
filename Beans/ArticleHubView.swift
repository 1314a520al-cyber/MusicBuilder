import SwiftUI

struct ArticleHubView: View {
        @StateObject private var theme = ThemeStore.shared
    
    enum ArticleModule: String, CaseIterable {
        case music = "音乐"
        case novel = "小说"
        case comic = "漫画"
        case audiobook = "有声书"
        
        var icon: String {
            switch self {
            case .music: return "music.note"
            case .novel: return "book.fill"
            case .comic: return "photo.on.rectangle"
            case .audiobook: return "headphones"
            }
        }
        
        var gradient: [Color] {
            switch self {
            case .music: return [Color(red:0.95,green:0.4,blue:0.5), Color(red:0.7,green:0.25,blue:0.45)]
            case .novel: return [Color(red:0.35,green:0.6,blue:0.95), Color(red:0.2,green:0.4,blue:0.8)]
            case .comic: return [Color(red:0.95,green:0.65,blue:0.25), Color(red:0.85,green:0.45,blue:0.15)]
            case .audiobook: return [Color(red:0.45,green:0.8,blue:0.55), Color(red:0.25,green:0.6,blue:0.4)]
            }
        }
        
        var desc: String {
            switch self {
            case .music: return "海量音源 · 无损音质"
            case .novel: return "百万小说 · 沉浸阅读"
            case .comic: return "热门漫画 · 高清阅读"
            case .audiobook: return "精品有声 · 解放双眼"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 顶部标题
                        VStack(spacing: 8) {
                            Text("Article")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .purple, .pink],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            Text("音乐 · 小说 · 漫画 · 有声书")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                        
                        // 功能卡片 2x2
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(ArticleModule.allCases, id: \.self) { module in
                                ModuleCard(module: module)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // 最近阅读
                        VStack(alignment: .leading, spacing: 12) {
                            Text("最近")
                                .font(.headline)
                                .foregroundColor(.primary)
                            RecentActivityView()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // 缓存管理
                        VStack(alignment: .leading, spacing: 12) {
                            Text("管理")
                                .font(.headline)
                                .foregroundColor(.primary)
                            NavigationLink {
                                CacheManagerView()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("缓存管理")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text("分类清理 · 上限设置 · 13种缓存类型")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationDestination(for: ArticleModule.self) { module in
                ModuleContainerView(module: module)
            }
        }
    }
}

struct ModuleCard: View {
    let module: ArticleHubView.ArticleModule
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        NavigationLink(value: module) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: module.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                Spacer()
                Text(module.rawValue)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text(module.desc)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
            .padding(16)
            .background(
                LinearGradient(colors: module.gradient,
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: module.gradient[0].opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentActivityView: View {
    @StateObject private var theme = ThemeStore.shared
    @AppStorage("recent_novel") private var recentNovel = ""
    @AppStorage("recent_comic") private var recentComic = ""
    @AppStorage("recent_audiobook") private var recentAudiobook = ""
    
    var body: some View {
        VStack(spacing: 8) {
            if recentNovel.isEmpty && recentComic.isEmpty && recentAudiobook.isEmpty {
                Text("暂无阅读记录")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                if !recentNovel.isEmpty {
                    RecentRow(icon: "book.fill", color: .blue, title: recentNovel, type: "小说")
                }
                if !recentComic.isEmpty {
                    RecentRow(icon: "photo.on.rectangle", color: .orange, title: recentComic, type: "漫画")
                }
                if !recentAudiobook.isEmpty {
                    RecentRow(icon: "headphones", color: .green, title: recentAudiobook, type: "有声书")
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct RecentRow: View {
    let icon: String
    let color: Color
    let title: String
    let type: String
    @StateObject private var theme = ThemeStore.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
