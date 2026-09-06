import SwiftUI
import UIKit

@main
struct BeansApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var player = PlayerManager()
    @StateObject private var theme = ThemeStore.shared
    @StateObject private var favorites = FavoritesStore.shared
    @StateObject private var updates = UpdateStore.shared
    @AppStorage("beans.disclaimerAccepted") private var disclaimerAccepted = false
    @State private var showOnboarding = false

    init() {
        CrashLogger.install()
        PlayerManager.shared = player
        // 注册默认设置
        UserDefaults.standard.register(defaults: [
            "beans.hapticEnabled": true,
            "beans.autoPlayOnStartup": false,
            "beans.vinylRecordStyle": false,
        ])
        // 启动时自动添加当前版本的更新记录（确保更新弹窗显示最新版本）
        UpdateStore.shared.startupCheck()
        // 启动时初始化（与原始仓库一致，不延迟）
        FontManager.reinstallIfNeeded()
        HighRefreshKeeper.registerDefaults()
        HighRefreshKeeper.shared.configureFromDefaults()
        // 内存警告：清理缓存
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { _ in
            URLCache.shared.removeAllCachedResponses()
            BeansImageFileCache.removeAll()
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(auth)
                    .environmentObject(player)
                    .environmentObject(theme)
                    .environmentObject(favorites)
                    .environmentObject(updates)
                    .onAppear {
                        showOnboarding = !disclaimerAccepted
                        // 启动自动播放
                        if UserDefaults.standard.bool(forKey: "beans.autoPlayOnStartup"),
                           !player.queue.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                player.togglePlayPause()
                            }
                        }
                    }
                    .overlay {
                        if updates.showUpdatePrompt, let entry = updates.latestEntry {
                            UpdatePromptView(entry: entry,
                                onDownload: {
                                    UpdateStore.shared.markSeen()
                                    let ver = entry.version
                                    if let url = URL(string: "https://github.com/1314a520al-cyber/music/releases/download/v\(ver)/Music-\(ver).ipa") {
                                        UIApplication.shared.open(url)
                                    } else if let url = URL(string: "https://github.com/1314a520al-cyber/music/releases") {
                                        UIApplication.shared.open(url)
                                    }
                                },
                                onLater: {
                                    UpdateStore.shared.markSeen()
                                    ToastCenter.shared.show("已稍后提醒")
                                },
                                onCancel: {
                                    UpdateStore.shared.markSeen()
                                }
                            )
                            .environmentObject(theme)
                        }
                    }
                if showOnboarding {
                    OnboardingView {
                        disclaimerAccepted = true
                        withAnimation(.easeOut(duration: 0.3)) {
                            showOnboarding = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(50)
                }
            }

        }
    }
}
