import Foundation
import UIKit
/// 统一缓存清理：网络缓存（URLCache）+ 系统 Caches 目录 + 临时目录 + 内存图片/主页快照。
/// 不会触碰下载的歌曲、字体、壁纸、登录信息等用户数据。
enum CacheCleaner {
    /// 当前可清理缓存大小（字节）
    static func totalSize() -> Int64 {
        var total: Int64 = Int64(URLCache.shared.currentDiskUsage)
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            total += directorySize(caches)
        }
        total += directorySize(FileManager.default.temporaryDirectory)
        // 歌词缓存
        total += directorySize(lyricsCacheDirectory)
        // 封面缩略图缓存
        total += directorySize(thumbnailsDirectory)
        // WebKit 缓存
        if let wkCache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("WebKit") {
            total += directorySize(wkCache)
        }
        return total
    }

    /// 歌词缓存目录
    private static var lyricsCacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("LyricsCache") ?? FileManager.default.temporaryDirectory
    }

    /// 封面缩略图缓存目录
    private static var thumbnailsDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Thumbnails") ?? FileManager.default.temporaryDirectory
    }
    /// 执行清理
    static func clear() {
        // 1. 网络请求 / 图片磁盘缓存
        URLCache.shared.removeAllCachedResponses()
        // 2. 内存中的图片解码缓存与主页数据快照
        BeansImageFileCache.removeAll()
        DiscoverCache.shared.clear()
        // 3. 歌词缓存
        clearContents(of: lyricsCacheDirectory)
        // 4. 封面缩略图缓存
        clearContents(of: thumbnailsDirectory)
        // 5. WebKit 缓存
        if let wkCache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("WebKit") {
            clearContents(of: wkCache)
        }
        // 6. 系统 Caches 目录与临时目录内容（保留目录本身）
        let fm = FileManager.default
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            clearContents(of: caches)
        }
        clearContents(of: fm.temporaryDirectory)
    }
    /// 人类可读的体积文本
    static func formatted(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(0, bytes))
    }
    private static func clearContents(of directory: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for item in items {
            try? fm.removeItem(at: item)
        }
    }
    private static func directorySize(_ directory: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }
}
