import SwiftUI

// MARK: - 相对时间

func beansRelativeTime(_ date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "刚刚" }
    if interval < 3600 { return "\(Int(interval / 60)) 分钟前" }
    if interval < 86400 { return "\(Int(interval / 3600)) 小时前" }
    if interval < 86400 * 30 { return "\(Int(interval / 86400)) 天前" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

// MARK: - 评论区

struct CommentsSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    let song: Song

    @State private var page: NetEaseAPI.SongCommentPage?
    @State private var qqComments: [SongComment] = []
    @State private var qqTotal = 0
    @State private var qqPageNum = 0
    @State private var kugouComments: [SongComment] = []
    @State private var kugouTotal = 0
    @State private var kugouPageNum = 1
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var offset = 0
    @State private var newComment = ""
    @State private var posting = false
    @State private var postError = ""
    @ObservedObject private var myComments = MyCommentsStore.shared
    @State private var showMyComments = false

    private let limit = 30
    /// QQ 音乐每页条数（接口单页上限 25）
    private let qqPageSize = 25

    var body: some View {
        let _ = theme.accent
        ZStack {
            GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            BeansNavigationStack {
                Group {
                    if loading {
                        LoadingStateView()
                    } else if let errorMessage {
                        ErrorStateView(message: errorMessage) {
                            Task { await load(reset: true) }
                        }
                    } else if song.source == .kugou {
                        kugouCommentList
                    } else if song.source == .qq {
                        qqCommentList
                    } else if let page {
                        if page.hot.isEmpty && page.comments.isEmpty {
                            EmptyStateView(icon: "bubble.left", text: "暂无评论")
                        } else {
                            neteaseCommentList(page)
                        }
                    }
                }
                .navigationTitle("评论")
                .navigationBarTitleDisplayMode(.inline)
            }
            .safeAreaInset(edge: .bottom) {
                if song.source == .netease {
                    commentInputBar
                }
            }
        }
        .task { await load(reset: true) }
    }

    private func neteaseCommentList(_ page: NetEaseAPI.SongCommentPage) -> some View {
        List {
            // 我的评论（折叠）
            let mine = myComments.commentsFor(songID: song.id)
            if !mine.isEmpty {
                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showMyComments.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.accent.highlight)
                            Text("我的评论 (\(mine.count))")
                                .font(BeansFont.appFont(13, .semibold))
                                .foregroundStyle(Color.beansLabel)
                            Spacer()
                            Image(systemName: showMyComments ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.beansComment)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    if showMyComments {
                        ForEach(mine) { c in
                            MyCommentRow(comment: c)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
            Section {
                Text("《\(song.name)》 · 共 \(page.total) 条评论")
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
            }
            .listRowBackground(Color.clear)
            if !page.hot.isEmpty {
                Section("精彩评论") {
                    ForEach(page.hot) { comment in
                        CommentRow(comment: comment)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            if !page.comments.isEmpty {
                Section("最新评论") {
                    ForEach(page.comments) { comment in
                        CommentRow(comment: comment)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            if page.comments.count >= limit {
                Section {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        Text("加载更多")
                            .font(BeansFont.appFont(14, .semibold))
                            .foregroundStyle(Color.beansAmber)
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .beansScrollContentBackgroundHidden()
    }

    private func load(reset: Bool) async {
        if reset {
            offset = 0
            page = nil
            qqComments = []
            qqTotal = 0
            qqPageNum = 0
            kugouComments = []
            kugouTotal = 0
            kugouPageNum = 1
            loading = true
        }
        errorMessage = nil
        do {
            if song.source == .kugou {
                let mixSongID = song.kugouAlbumAudioId ?? ""
                let result = try await KugouMusicAPI.shared.comments(
                    mixSongID: mixSongID,
                    hash: song.kugouHash,
                    page: kugouPageNum,
                    limit: limit
                )
                if reset {
                    kugouComments = result.comments
                } else {
                    kugouComments.append(contentsOf: result.comments)
                }
                kugouTotal = result.total
                loading = false
                return
            } else if song.source == .qq {
                let result = try await QQMusicAPI.shared.comments(songID: song.id, limit: qqPageSize, pagenum: qqPageNum)
                if reset {
                    qqComments = result.comments
                } else {
                    qqComments.append(contentsOf: result.comments)
                }
                qqTotal = result.total
            } else {
                let result = try await NetEaseAPI.shared.songComments(id: song.id, limit: limit, offset: offset)
                if reset {
                    page = result
                } else if var current = page {
                    current.comments.append(contentsOf: result.comments)
                    page = current
                }
            }
            loading = false
        } catch {
            errorMessage = error.localizedDescription
            loading = false
        }
    }

    /// QQ 音乐评论列表（分页加载更多）
    private var qqCommentList: some View {
        Group {
            if qqComments.isEmpty {
                EmptyStateView(icon: "bubble.left", text: "暂无评论")
            } else {
                List {
                    Section {
                        Text(qqTotal > 0
                            ? "《\(song.name)》 · QQ 音乐 \(qqTotal) 条评论"
                            : "《\(song.name)》 · QQ 音乐 \(qqComments.count) 条评论")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                    }
                    .listRowBackground(Color.clear)
                    Section("评论") {
                        ForEach(qqComments) { comment in
                            CommentRow(comment: comment)
                                .listRowBackground(Color.clear)
                        }
                    }
                    if qqTotal <= 0 || qqComments.count < qqTotal {
                        Section {
                            Button {
                                Task { await loadQQMore() }
                            } label: {
                                Text("加载更多")
                                    .font(BeansFont.appFont(14, .semibold))
                                    .foregroundStyle(Color.beansAmber)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .beansScrollContentBackgroundHidden()
            }
        }
    }

    /// QQ 评论翻页
    private func loadQQMore() async {
        qqPageNum += 1
        await load(reset: false)
    }

    private var kugouCommentList: some View {
        Group {
            if kugouComments.isEmpty {
                EmptyStateView(icon: "bubble.left", text: "暂无评论")
            } else {
                List {
                    Section {
                        Text(kugouTotal > 0
                            ? "《\(song.name)》 · 酷狗音乐 \(kugouTotal) 条评论"
                            : "《\(song.name)》 · 酷狗音乐 \(kugouComments.count) 条评论")
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                    }
                    .listRowBackground(Color.clear)
                    Section("评论") {
                        ForEach(kugouComments) { comment in
                            CommentRow(comment: comment)
                                .listRowBackground(Color.clear)
                        }
                    }
                    if kugouTotal <= 0 || kugouComments.count < kugouTotal {
                        Section {
                            Button {
                                kugouPageNum += 1
                                Task { await load(reset: false) }
                            } label: {
                                Text("加载更多")
                                    .font(BeansFont.appFont(14, .semibold))
                                    .foregroundStyle(Color.beansAmber)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .beansScrollContentBackgroundHidden()
            }
        }
    }

    private func loadMore() async {
        offset += limit
        await load(reset: false)
    }

    // MARK: - 发评论
    private var commentInputBar: some View {
        VStack(spacing: 0) {
            if !postError.isEmpty {
                Text(postError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16).padding(.top, 6)
            }
            HStack(spacing: 10) {
                TextField("发表评论（网易云）", text: $newComment)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                Button {
                    postComment()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(newComment.trimmingCharacters(in: .whitespaces).isEmpty || posting ? Color.gray : theme.accent.highlight))
                }
                .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty || posting)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private func postComment() {
        let content = newComment.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        // 收起键盘
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        posting = true
        postError = ""
        let songName = song.name
        Task {
            let ok = await NetEaseAPI.shared.postComment(songID: song.id, content: content)
            await MainActor.run {
                posting = false
                if ok {
                    newComment = ""
                    // 保存到我的评论
                    MyCommentsStore.shared.add(songID: song.id, songName: songName, content: content, platform: "netease")
                    showMyComments = true
                    ToastCenter.shared.show("评论已发布")
                    offset = 0
                    Task { await load(reset: true) }
                } else {
                    postError = "发布失败，请确认已登录网易云"
                }
            }
        }
    }
}

// MARK: - 评论行

struct CommentRow: View {
    @EnvironmentObject private var theme: ThemeStore
    let comment: SongComment

    var body: some View {
        let _ = theme.accent
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: comment.avatarURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.beansComment)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .background(Color.beansGlassFill, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(comment.nickname)
                        .font(BeansFont.appFont(13, .medium))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(1)
                    if comment.isHot {
                        Text("热评")
                            .font(BeansFont.appFont(9, .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(LinearGradient.beansAccent, in: Capsule())
                    }
                    Spacer()
                    Text(beansRelativeTime(comment.time))
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment.opacity(0.8))
                }
                Text(comment.content)
                    .font(BeansFont.appFont(14))
                    .foregroundStyle(Color.beansLabel)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Label("\(comment.likedCount)", systemImage: "heart")
                        .font(BeansFont.appFont(11, .medium))
                        .foregroundStyle(Color.beansComment)
                        .labelStyle(.trailingIcon)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 我的评论行
struct MyCommentRow: View {
    @EnvironmentObject private var theme: ThemeStore
    let comment: SentComment

    var body: some View {
        let _ = theme.accent
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(theme.accent.highlight)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("我")
                        .font(BeansFont.appFont(13, .bold))
                        .foregroundStyle(theme.accent.highlight)
                    Text(beansRelativeTime(comment.time))
                        .font(BeansFont.appFont(10))
                        .foregroundStyle(Color.beansComment.opacity(0.7))
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
                Text(comment.content)
                    .font(BeansFont.appFont(14))
                    .foregroundStyle(Color.beansLabel)
                    .fixedSize(horizontal: false, vertical: true)
                Text("《\(comment.songName)》")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.accent.highlight.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.accent.highlight.opacity(0.15), lineWidth: 1)
        )
        .padding(.vertical, 2)
    }
}

// 图标在文字后面
extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

// MARK: - 账号页：我的评论历史（折叠）
struct MyCommentsHistorySection: View {
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var store = MyCommentsStore.shared
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accent.highlight)
                    Text("我的评论")
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text("(\(store.comments.count))")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.beansComment)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if expanded {
                if store.comments.isEmpty {
                    Text("还没有发表过评论")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.comments.prefix(20)) { c in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("《\(c.songName)》")
                                        .font(BeansFont.appFont(11, .semibold))
                                        .foregroundStyle(theme.accent.highlight)
                                    Spacer()
                                    Text(beansRelativeTime(c.time))
                                        .font(BeansFont.appFont(10))
                                        .foregroundStyle(Color.beansComment.opacity(0.7))
                                }
                                Text(c.content)
                                    .font(BeansFont.appFont(13))
                                    .foregroundStyle(Color.beansLabel)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
                        }
                        if store.comments.count > 20 {
                            Text("仅显示最近 20 条")
                                .font(BeansFont.appFont(10))
                                .foregroundStyle(Color.beansComment.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 4)
    }
}
