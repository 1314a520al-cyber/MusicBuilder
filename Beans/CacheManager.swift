import Foundation
import UIKit
import SwiftUI

// MARK: - 增强缓存管理：分类占比 / 上限 / 可折叠

struct CacheCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let size: Int64
    let color: Color
}

enum CacheManager {
    static let limitKey = "beans.cache.limitMB"
    static let defaultLimitMB = 500

    static var limitMB: Int {
        get { UserDefaults.standard.integer(forKey: limitKey) > 0 ? UserDefaults.standard.integer(forKey: limitKey) : defaultLimitMB }
        set { UserDefaults.standard.set(newValue, forKey: limitKey) }
    }

    static var limitExceeded: Bool {
        totalSize() > Int64(limitMB) * 1024 * 1024
    }

    static func totalSize() -> Int64 {
        categories().reduce(0) { $0 + $1.size }
    }

    static func categories() -> [CacheCategory] {
        let fm = FileManager.default
        // 网络缓存
        let networkCache = Int64(URLCache.shared.currentDiskUsage)
        // 图片缓存
        let imageCache = directorySize(in: .cachesDirectory, subpath: "images") + directorySize(in: .cachesDirectory, subpath: "com.apple.nsurlsessiond")
        // 封面/歌词缓存
        let coverCache = directorySize(in: .cachesDirectory, subpath: "covers")
        let lyricCache = directorySize(in: .cachesDirectory, subpath: "lyrics")
        // 临时文件
        let tempFiles = directorySize(fm.temporaryDirectory)
        // 下载的歌曲（单独统计，不自动清理）
        let downloads = directorySize(in: .documentDirectory, subpath: "Downloads")
        // 其他缓存
        let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
        let otherCache = (cachesDir.map { directorySize($0) } ?? 0) - imageCache - coverCache - lyricCache

        return [
            CacheCategory(name: "网络缓存", icon: "network", size: networkCache, color: .blue),
            CacheCategory(name: "图片缓存", icon: "photo", size: max(0, imageCache), color: .purple),
            CacheCategory(name: "封面缓存", icon: "music.note", size: coverCache, color: .pink),
            CacheCategory(name: "歌词缓存", icon: "text.alignleft", size: lyricCache, color: .orange),
            CacheCategory(name: "临时文件", icon: "tray", size: tempFiles, color: .gray),
            CacheCategory(name: "其他缓存", icon: "square.stack", size: max(0, otherCache), color: .teal),
            CacheCategory(name: "已下载歌曲", icon: "arrow.down.circle.fill", size: downloads, color: .green),
        ]
    }

    static func clearAll() {
        URLCache.shared.removeAllCachedResponses()
        BeansImageFileCache.removeAll()
        DiscoverCache.shared.clear()
        let fm = FileManager.default
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            clearContents(of: caches)
        }
        clearContents(of: fm.temporaryDirectory)
    }

    static func clearCategory(_ name: String) {
        let fm = FileManager.default
        switch name {
        case "网络缓存":
            URLCache.shared.removeAllCachedResponses()
        case "图片缓存":
            removeSubpath(in: .cachesDirectory, subpath: "images")
        case "封面缓存":
            removeSubpath(in: .cachesDirectory, subpath: "covers")
        case "歌词缓存":
            removeSubpath(in: .cachesDirectory, subpath: "lyrics")
        case "临时文件":
            clearContents(of: fm.temporaryDirectory)
        case "其他缓存":
            if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                clearContents(of: caches, keep: ["images", "covers", "lyrics"])
            }
        default: break
        }
    }

    static func formatted(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(0, bytes))
    }

    // MARK: - Private

    private static func directorySize(in domain: FileManager.SearchPathDirectory, subpath: String) -> Int64 {
        guard let dir = FileManager.default.urls(for: domain, in: .userDomainMask).first?
            .appendingPathComponent(subpath) else { return 0 }
        return directorySize(dir)
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

    private static func clearContents(of directory: URL, keep: [String] = []) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for item in items {
            if keep.contains(item.lastPathComponent) { continue }
            try? fm.removeItem(at: item)
        }
    }

    private static func removeSubpath(in domain: FileManager.SearchPathDirectory, subpath: String) {
        guard let dir = FileManager.default.urls(for: domain, in: .userDomainMask).first?
            .appendingPathComponent(subpath) else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}
