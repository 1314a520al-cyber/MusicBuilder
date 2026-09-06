import SwiftUI

@main
struct NovelApp: App {
    @StateObject private var bookshelf = BookshelfStore.shared
    @StateObject private var sourceManager = NovelSourceManager.shared
    @StateObject private var theme = NovelTheme.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var cacheManager = CacheManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bookshelf)
                .environmentObject(sourceManager)
                .environmentObject(theme)
                .environmentObject(downloadManager)
                .environmentObject(cacheManager)
                .preferredColorScheme(theme.isDarkMode ? .dark : .light)
        }
    }
}
