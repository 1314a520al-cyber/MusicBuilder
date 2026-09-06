import SwiftUI

struct ProfileView: View {
    @ObservedObject private var theme = NovelTheme.shared
    @State private var showSourceManager = false
    @State private var showCacheManager = false
    @State private var showDownloadManager = false
    @State private var showSettings = false
    @State private var showAbout = false
    @State private var showBackup = false
    
    var body: some View {
        NavigationStack {
            List {
                // 用户信息区
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(theme.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("笔趣阁用户")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("本地阅读 · 无需登录")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                // 核心功能
                Section {
                    profileRow(icon: "externaldrive.connected.to.line.below", title: "书源管理", subtitle: "导入/编辑/调试书源") {
                        showSourceManager = true
                    }
                    profileRow(icon: "arrow.down.circle", title: "下载管理", subtitle: "已下载书籍/章节") {
                        showDownloadManager = true
                    }
                    profileRow(icon: "trash", title: "缓存清理", subtitle: "清理阅读缓存/图片缓存") {
                        showCacheManager = true
                    }
                    profileRow(icon: "icloud.and.arrow.up", title: "备份恢复", subtitle: "备份书架/书源/阅读记录") {
                        showBackup = true
                    }
                }
                
                // 阅读设置
                Section {
                    profileRow(icon: "slider.horizontal.3", title: "阅读设置", subtitle: "字体/背景/翻页模式") {
                        showSettings = true
                    }
                    profileRow(icon: "textformat.size", title: "字体管理", subtitle: "添加/管理字体") {}
                    profileRow(icon: "paintpalette", title: "主题设置", subtitle: "深色/浅色/自定义主题") {}
                }
                
                // 其他
                Section {
                    profileRow(icon: "clock.arrow.circlepath", title: "阅读记录", subtitle: "阅读时长/统计") {}
                    profileRow(icon: "folder", title: "本地导入", subtitle: "TXT/EPUB导入") {}
                    profileRow(icon: "info.circle", title: "关于", subtitle: "版本信息/联系我们") {
                        showAbout = true
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSourceManager) {
                SourceManagerView()
            }
            .sheet(isPresented: $showCacheManager) {
                CacheManagerView()
            }
            .sheet(isPresented: $showDownloadManager) {
                DownloadManagerView()
            }
            .sheet(isPresented: $showSettings) {
                ReadingSettingsView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showBackup) {
                BackupView()
            }
        }
    }
    
    private func profileRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 4)
        }
    }
}

// 缓存清理页面
struct CacheManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = NovelTheme.shared
    @State private var cacheTypes: [CacheType] = [
        CacheType(name: "书籍内容缓存", size: "12.5 MB", icon: "book", selected: true),
        CacheType(name: "封面图片缓存", size: "8.3 MB", icon: "photo", selected: true),
        CacheType(name: "章节列表缓存", size: "3.2 MB", icon: "list.bullet", selected: true),
        CacheType(name: "搜索历史缓存", size: "0.5 MB", icon: "magnifyingglass", selected: false),
        CacheType(name: "阅读进度缓存", size: "1.1 MB", icon: "clock", selected: false),
    ]
    @State private var isClearing = false
    @State private var showResult = false
    
    var totalSize: String {
        let total = cacheTypes.filter { $0.selected }.reduce(0.0) { sum, type in
            sum + (Double(type.size.replacingOccurrences(of: " MB", with: "")) ?? 0)
        }
        return String(format: "%.1f MB", total)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($cacheTypes) { $type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundStyle(theme.accentColor)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(type.name)
                                    .foregroundStyle(.white)
                                Text(type.size)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                            Spacer()
                            Toggle("", isOn: $type.selected)
                                .labelsHidden()
                                .tint(theme.accentColor)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("选择要清理的缓存类型")
                } footer: {
                    Text("已选缓存大小：\(totalSize)")
                }
                
                Section {
                    Button {
                        clearCache()
                    } label: {
                        HStack {
                            Spacer()
                            if isClearing {
                                ProgressView()
                            } else {
                                Text("清理选中缓存")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.red)
                    }
                    .disabled(isClearing)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("缓存清理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("清理完成", isPresented: $showResult) {
                Button("确定") { dismiss() }
            } message: {
                Text("已成功清理 \(totalSize) 缓存")
            }
        }
    }
    
    private func clearCache() {
        isClearing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 清理选中的缓存
            for i in cacheTypes.indices {
                if cacheTypes[i].selected {
                    cacheTypes[i].size = "0 MB"
                    cacheTypes[i].selected = false
                }
            }
            isClearing = false
            showResult = true
        }
    }
}

struct CacheType: Identifiable {
    let id = UUID()
    let name: String
    var size: String
    let icon: String
    var selected: Bool
}

// 下载管理页面
struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = NovelTheme.shared
    @State private var downloadedBooks: [DownloadedBook] = [
        DownloadedBook(title: "斗破苍穹", author: "天蚕土豆", chapters: 500, totalChapters: 1648, size: "45.2 MB"),
        DownloadedBook(title: "完美世界", author: "辰东", chapters: 200, totalChapters: 2014, size: "18.5 MB"),
        DownloadedBook(title: "遮天", author: "辰东", chapters: 1000, totalChapters: 1880, size: "89.3 MB"),
    ]
    @State private var showDeleteConfirm = false
    @State private var bookToDelete: DownloadedBook?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(downloadedBooks) { book in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                            Text(book.author)
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                            Text("已下载 \(book.chapters)/\(book.totalChapters) 章 · \(book.size)")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray.opacity(0.8))
                            // 进度条
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Color.gray.opacity(0.3)
                                    theme.accentColor
                                        .frame(width: geo.size.width * Double(book.chapters) / Double(book.totalChapters))
                                }
                            }
                            .frame(height: 3)
                        }
                        
                        Spacer()
                        
                        Button {
                            bookToDelete = book
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { indexSet in
                    downloadedBooks.remove(atOffsets: indexSet)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("下载管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            // 保存到系统文件夹
                        } label: {
                            Label("导出到文件", systemImage: "folder")
                        }
                        Button(role: .destructive) {
                            downloadedBooks.removeAll()
                        } label: {
                            Label("清空全部下载", systemImage: "trash.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let book = bookToDelete, let index = downloadedBooks.firstIndex(where: { $0.id == book.id }) {
                        downloadedBooks.remove(at: index)
                    }
                }
            } message: {
                Text("确定要删除「\(bookToDelete?.title ?? "")」的下载内容吗？")
            }
            .overlay {
                if downloadedBooks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray)
                        Text("暂无下载内容")
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }
}

struct DownloadedBook: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let chapters: Int
    let totalChapters: Int
    let size: String
}

// 关于页面
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)
                            Text("笔趣阁")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("版本 2.0.0")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
                .listRowBackground(Color.clear)
                
                Section("联系我们") {
                    LabeledContent("邮箱", value: "azedix@yeah.net")
                    LabeledContent("反馈", value: "应用内反馈")
                }
                
                Section("开源说明") {
                    Text("本应用基于开源阅读项目二次开发，支持自定义书源、本地阅读等功能。")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// 备份页面
struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("备份") {
                    Button {
                        // 备份到文件
                    } label: {
                        Label("备份到文件", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        // 备份到iCloud
                    } label: {
                        Label("备份到iCloud", systemImage: "icloud.and.arrow.up")
                    }
                }
                
                Section("恢复") {
                    Button {
                        // 从文件恢复
                    } label: {
                        Label("从文件恢复", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        // 从iCloud恢复
                    } label: {
                        Label("从iCloud恢复", systemImage: "icloud.and.arrow.down")
                    }
                }
                
                Section("备份内容") {
                    Toggle("书架", isOn: .constant(true))
                    Toggle("书源", isOn: .constant(true))
                    Toggle("阅读记录", isOn: .constant(true))
                    Toggle("阅读设置", isOn: .constant(true))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("备份恢复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
