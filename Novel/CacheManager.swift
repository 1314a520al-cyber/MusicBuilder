import Foundation

class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    @Published var cacheSize: Int64 = 0
    @Published var isClearing = false
    
    private let fileManager = FileManager.default
    private var cacheDir: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("NovelCache", isDirectory: true)
    }
    
    init() {
        calculateCacheSize()
    }
    
    func calculateCacheSize() {
        var totalSize: Int64 = 0
        
        // 计算缓存目录大小
        if let enumerator = fileManager.enumerator(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        
        // 加上UserDefaults中的缓存（搜索历史等）
        if let history = UserDefaults.standard.stringArray(forKey: "novel.searchHistory") {
            totalSize += Int64(history.joined().count * 2)
        }
        
        cacheSize = totalSize
    }
    
    func clearCache(completion: @escaping () -> Void) {
        isClearing = true
        
        Task {
            // 删除缓存目录
            try? fileManager.removeItem(at: cacheDir)
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            // 清除URLCache
            URLCache.shared.removeAllCachedResponses()
            
            // 清除搜索历史（可选，这里保留）
            // UserDefaults.standard.removeObject(forKey: "novel.searchHistory")
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                calculateCacheSize()
                isClearing = false
                completion()
            }
        }
    }
    
    func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }
    
    // 缓存章节内容到内存
    private var chapterCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 50
        return cache
    }()
    
    func cacheChapter(url: String, content: String) {
        chapterCache.setObject(content as NSString, forKey: url as NSString)
    }
    
    func getCachedChapter(url: String) -> String? {
        return chapterCache.object(forKey: url as NSString) as String?
    }
}
