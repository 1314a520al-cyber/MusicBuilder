import SwiftUI

// MARK: - 云端音乐页面（网盘 + QQ + 网易云 + 酷狗，四大分类折叠）

struct CloudMusicView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @StateObject private var store = CloudMusicStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var expandedSections: Set<String> = []
    @State private var selectedPlaylist: Playlist?
    @State private var selectedSource: CloudMusicStore.CloudSection?
    @State private var showPlaylistSongs = false
    @State private var playlistSongs: [Song] = []
    @State private var loadingPlaylist = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 网盘音乐
                        cloudSection(
                            title: "网盘音乐",
                            icon: "externaldrive.fill",
                            color: .blue,
                            section: .netdisk,
                            isLoggedIn: CloudDriveStore.shared.loggedInCount > 0,
                            loginHint: "请先在设置中登录网盘"
                        ) {
                            if store.netdiskSongs.isEmpty {
                                emptyView(text: "暂无网盘音乐，登录后自动识别")
                            } else {
                                ForEach(store.netdiskSongs) { song in
                                    netdiskSongRow(song)
                                }
                            }
                        }
                        
                        // QQ音乐
                        cloudSection(
                            title: "QQ音乐",
                            icon: "music.note",
                            color: .green,
                            section: .qq,
                            isLoggedIn: !QQMusicAuth.shared.uin.isEmpty,
                            loginHint: "请先登录QQ音乐"
                        ) {
                            if store.qqPlaylists.isEmpty {
                                emptyView(text: "暂无歌单")
                            } else {
                                ForEach(store.qqPlaylists) { pl in
                                    playlistRow(pl, source: .qq)
                                }
                            }
                        }
                        
                        // 网易云音乐
                        cloudSection(
                            title: "网易云音乐",
                            icon: "cloud.fill",
                            color: .red,
                            section: .netease,
                            isLoggedIn: UserDefaults.standard.data(forKey: "beans.user") != nil,
                            loginHint: "请先登录网易云音乐"
                        ) {
                            if store.neteasePlaylists.isEmpty {
                                emptyView(text: "暂无歌单")
                            } else {
                                ForEach(store.neteasePlaylists) { pl in
                                    playlistRow(pl, source: .netease)
                                }
                            }
                        }
                        
                        // 酷狗音乐
                        cloudSection(
                            title: "酷狗音乐",
                            icon: "headphones",
                            color: .orange,
                            section: .kugou,
                            isLoggedIn: KugouMusicAuth.shared.isLoggedIn,
                            loginHint: "请先登录酷狗音乐"
                        ) {
                            if store.kugouPlaylists.isEmpty {
                                emptyView(text: "暂无歌单")
                            } else {
                                ForEach(store.kugouPlaylists) { pl in
                                    playlistRow(pl, source: .kugou)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("云端音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await store.loadNetdiskSongs()
                            await store.loadQQPlaylists()
                            await store.loadNeteasePlaylists()
                            await store.loadKugouPlaylists()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                }
            }
            .sheet(isPresented: $showPlaylistSongs) {
                playlistSongsView
            }
        }
    }
    
    // MARK: - 分类卡片
    
    private func cloudSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        section: CloudMusicStore.CloudSection,
        isLoggedIn: Bool,
        loginHint: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let expanded = expandedSections.contains(title)
        
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedSections.contains(title) {
                        expandedSections.remove(title)
                    } else {
                        expandedSections.insert(title)
                        // 展开时加载
                        Task {
                            switch section {
                            case .netdisk: await store.loadNetdiskSongs()
                            case .qq: await store.loadQQPlaylists()
                            case .netease: await store.loadNeteasePlaylists()
                            case .kugou: await store.loadKugouPlaylists()
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(isLoggedIn ? "已登录" : loginHint)
                            .font(.caption)
                            .foregroundColor(isLoggedIn ? .green : .secondary)
                    }
                    
                    Spacer()
                    
                    if store.loadingSection == section {
                        ProgressView()
                    }
                    
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12, corners: expanded ? [.topLeft, .topRight] : .allCorners)
            }
            .buttonStyle(.plain)
            
            if expanded {
                Divider()
                VStack(spacing: 0) {
                    content()
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - 歌单行
    
    private func playlistRow(_ playlist: Playlist, source: CloudMusicStore.CloudSection) -> some View {
        Button {
            selectedPlaylist = playlist
            selectedSource = source
            loadingPlaylist = true
            Task {
                playlistSongs = await store.loadPlaylistSongs(playlist: playlist, source: source)
                loadingPlaylist = false
                showPlaylistSongs = true
            }
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: playlist.coverURL) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 44, height: 44)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(playlist.trackCount)首")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if loadingPlaylist && selectedPlaylist?.id == playlist.id {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 网盘歌曲行
    
    private func netdiskSongRow(_ song: CloudMusicStore.NetdiskSong) -> some View {
        Button {
            store.playNetdiskSong(song)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(song.driveName) · \(formattedSize(song.size))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 歌单歌曲页面
    
    private var playlistSongsView: some View {
        NavigationStack {
            List {
                if playlistSongs.isEmpty {
                    Text("暂无歌曲")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(playlistSongs.enumerated()), id: \.element.identityKey) { idx, song in
                        Button {
                            player.play(songs: playlistSongs, startAt: idx)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(idx + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(song.artists)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(selectedPlaylist?.name ?? "歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showPlaylistSongs = false }
                }
            }
        }
    }
    
    // MARK: - 空视图
    
    private func emptyView(text: String) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 20)
            Spacer()
        }
    }
    
    private func formattedSize(_ bytes: Int64) -> String {
        if bytes < 1024 * 1024 {
            return String(format: "%.0fKB", Double(bytes) / 1024)
        }
        return String(format: "%.1fMB", Double(bytes) / 1024 / 1024)
    }
}

// MARK: - 圆角扩展

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
