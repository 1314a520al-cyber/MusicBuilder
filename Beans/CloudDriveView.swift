import SwiftUI
import WebKit

/// 网盘账号
struct CloudDriveAccount: Codable, Identifiable, Equatable {
    let id: String
    var name: String  // 迅雷/夸克/UC
    var displayName: String
    var isLoggedIn: Bool
    var cookies: String?  // 登录后的 cookie
    var loginURL: String
}

/// 网盘管理
final class CloudDriveStore: ObservableObject {
    static let shared = CloudDriveStore()
    @Published private(set) var accounts: [CloudDriveAccount] = []
    private let key = "music.cloud.drives.v1"

    let driveTypes: [(name: String, url: String, icon: String)] = [
        ("迅雷云盘", "https://pan.xunlei.com", "bolt.fill"),
        ("夸克网盘", "https://pan.quark.cn", "square.stack.3d.up.fill"),
        ("UC 网盘", "https://drive.uc.cn", "globe"),
    ]

    private init() {
        load()
        if accounts.isEmpty {
            accounts = driveTypes.map { type in
                CloudDriveAccount(id: type.name, name: type.name, displayName: type.name, isLoggedIn: false, cookies: nil, loginURL: type.url)
            }
            save()
        }
    }

    func setLoggedIn(_ id: String, loggedIn: Bool, cookies: String? = nil, displayName: String? = nil) {
        guard let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        guard accounts.indices.contains(idx) else { return }
        accounts[idx].isLoggedIn = loggedIn
        if let cookies { accounts[idx].cookies = cookies }
        if let displayName { accounts[idx].displayName = displayName }
        save()
    }

    func logout(_ id: String) {
        setLoggedIn(id, loggedIn: false, cookies: nil)
    }

    var loggedInCount: Int {
        accounts.filter { $0.isLoggedIn }.count
    }

    private func save() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([CloudDriveAccount].self, from: data) else { return }
        accounts = arr
    }
}

/// 网盘管理页面（折叠式）
struct CloudDriveView: View {
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var store = CloudDriveStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var expanded = true
    @State private var loginDrive: CloudDriveAccount?
    @State private var showDriveFiles = false
    @State private var selectedDrive: CloudDriveAccount?

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                List {
                    Section {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "externaldrive.fill")
                                    .foregroundStyle(theme.accent.highlight)
                                Text("网盘管理")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                Text("\(store.loggedInCount)/\(store.accounts.count) 已登录")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.beansComment)
                                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment)
                            }
                        }
                        .buttonStyle(.plain)

                        if expanded {
                            ForEach(store.accounts) { account in
                                driveRow(account)
                            }
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("功能说明", systemImage: "info.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.beansAmber)
                            Text("• 登录网盘后可浏览网盘中的音乐文件")
                            Text("• 识别到的音乐自动加入「云端歌曲」")
                            Text("• 支持备份播放列表和设置到网盘")
                            Text("• 通过网页扫码或账号密码登录")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansComment)
                        .padding(.vertical, 4)
                    }
                }
                .beansScrollContentBackgroundHidden()
            }
            .navigationTitle("网盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $loginDrive) { drive in
                DriveLoginView(drive: drive)
            }
            .sheet(isPresented: $showDriveFiles) {
                if let drive = selectedDrive {
                    DriveFilesView(drive: drive)
                }
            }
        }
    }

    private func driveRow(_ account: CloudDriveAccount) -> some View {
        let icon = store.driveTypes.first { $0.name == account.name }?.icon ?? "externaldrive"
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(account.isLoggedIn ? .green : Color.beansComment)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(account.isLoggedIn ? Color.green.opacity(0.15) : Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 3) {
                Text(account.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.beansLabel)
                Text(account.isLoggedIn ? "已登录" : "未登录")
                    .font(.system(size: 11))
                    .foregroundStyle(account.isLoggedIn ? .green : Color.beansComment)
            }
            Spacer()
            if account.isLoggedIn {
                Button("浏览") {
                    selectedDrive = account
                    showDriveFiles = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent.highlight)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(theme.accent.highlight.opacity(0.15)))
                Button("退出") {
                    store.logout(account.id)
                    ToastCenter.shared.show("已退出 \(account.name)")
                }
                .font(.system(size: 13))
                .foregroundStyle(.red)
            } else {
                Button("登录") {
                    loginDrive = account
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(Capsule().fill(theme.accent.highlight))
            }
        }
        .padding(.vertical, 4)
    }
}

/// 网盘登录（WebView）
struct DriveLoginView: View {
    let drive: CloudDriveAccount
    @Environment(\.dismiss) private var dismiss
    @State private var webView: WKWebView?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WebViewRepresentable(urlString: drive.loginURL, webView: $webView)
                Button("完成登录") {
                    // 提取 cookie 并保存
                    webView?.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                        let cookieStr = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                        CloudDriveStore.shared.setLoggedIn(drive.id, loggedIn: true, cookies: cookieStr, displayName: drive.name)
                    }
                    ToastCenter.shared.show("\(drive.name) 登录成功")
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
            }
            .navigationTitle("登录 \(drive.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

/// 网盘文件浏览（模拟识别音乐）
struct DriveFilesView: View {
    let drive: CloudDriveAccount
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var files: [DriveFile] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                if loading {
                    ProgressView("加载文件…")
                } else if files.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.beansComment)
                        Text("暂无音乐文件")
                            .foregroundStyle(Color.beansComment)
                    }
                } else {
                    List(files) { file in
                        HStack(spacing: 12) {
                            Image(systemName: file.isMusic ? "music.note" : "doc")
                                .foregroundStyle(file.isMusic ? theme.accent.highlight : Color.beansComment)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.name)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                Text(file.size)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.beansComment)
                            }
                            Spacer()
                            if file.isMusic {
                                Button("识别") {
                                    let song = DetectedSong(id: file.id, name: file.name.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".flac", with: ""), artist: drive.name, source: drive.name, url: file.url)
                                    CloudSongsStore.shared.add([song])
                                    ToastCenter.shared.show("已添加到云端歌曲")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.green)
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                }
            }
            .navigationTitle(drive.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                // 模拟加载文件
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    files = [
                        DriveFile(id: "1", name: "歌曲1.mp3", size: "8.5 MB", isMusic: true, url: ""),
                        DriveFile(id: "2", name: "歌曲2.flac", size: "32 MB", isMusic: true, url: ""),
                        DriveFile(id: "3", name: "专辑.zip", size: "156 MB", isMusic: false, url: ""),
                        DriveFile(id: "4", name: "歌曲3.m4a", size: "6.2 MB", isMusic: true, url: ""),
                    ]
                    loading = false
                }
            }
        }
    }
}

struct DriveFile: Identifiable {
    let id: String
    let name: String
    let size: String
    let isMusic: Bool
    let url: String
}
