import Foundation
import SwiftUI

struct DownloadedChapter: Identifiable, Codable, Hashable {
    let id: String
    let novelId: String
    let novelTitle: String
    let chapterIndex: Int
    let chapterTitle: String
    let content: String
    let downloadDate: Date
    let folderPath: String
    var fileSize: Int64
}

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var downloads: [DownloadedChapter] = []
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var currentDownloadTitle = ""
    
    private let fileManager = FileManager.default
    private var downloadsDir: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("NovelDownloads", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    init() {
        loadDownloads()
    }
    
    func loadDownloads() {
        if let data = UserDefaults.standard.data(forKey: "novel.downloads"),
           let decoded = try? JSONDecoder().decode([DownloadedChapter].self, from: data) {
            downloads = decoded
        }
    }
    
    func saveDownloads() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: "novel.downloads")
        }
    }
    
    // 获取下载文件夹列表
    func getFolders() -> [String] {
        do {
            let items = try fileManager.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: nil)
            return items.filter { $0.hasDirectoryPath }.map { $0.lastPathComponent }
        } catch {
            return []
        }
    }
    
    // 创建文件夹
    func createFolder(_ name: String) -> Bool {
        let folderURL = downloadsDir.appendingPathComponent(name, isDirectory: true)
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
    
    // 下载章节
    func downloadChapter(novel: Novel, chapter: NovelChapter, content: String, folder: String) {
        isDownloading = true
        currentDownloadTitle = chapter.title
        downloadProgress = 0
        
        Task {
            // 模拟下载进度
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                await MainActor.run {
                    downloadProgress = Double(i) / 10.0
                }
            }
            
            // 保存文件
            let folderURL = downloadsDir.appendingPathComponent(folder, isDirectory: true)
            if !fileManager.fileExists(atPath: folderURL.path) {
                try? fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            
            let fileName = "\(novel.title)_\(chapter.index)_\(chapter.title).txt".replacingOccurrences(of: "/", with: "_")
            let fileURL = folderURL.appendingPathComponent(fileName)
            
            let fileContent = "书名：\(novel.title)\n作者：\(novel.author)\n章节：\(chapter.title)\n\n\(content)"
            let data = fileContent.data(using: .utf8)
            try? data?.write(to: fileURL)
            
            let fileSize = Int64(data?.count ?? 0)
            
            let downloaded = DownloadedChapter(
                id: UUID().uuidString,
                novelId: novel.id,
                novelTitle: novel.title,
                chapterIndex: chapter.index,
                chapterTitle: chapter.title,
                content: content,
                downloadDate: Date(),
                folderPath: folder,
                fileSize: fileSize
            )
            
            await MainActor.run {
                downloads.append(downloaded)
                saveDownloads()
                isDownloading = false
                downloadProgress = 0
                currentDownloadTitle = ""
            }
        }
    }
    
    // 删除下载
    func deleteDownload(_ download: DownloadedChapter) {
        let folderURL = downloadsDir.appendingPathComponent(download.folderPath, isDirectory: true)
        let fileName = "\(download.novelTitle)_\(download.chapterIndex)_\(download.chapterTitle).txt".replacingOccurrences(of: "/", with: "_")
        let fileURL = folderURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
        
        downloads.removeAll { $0.id == download.id }
        saveDownloads()
    }
    
    // 删除某本小说的所有下载
    func deleteNovelDownloads(novelId: String) {
        let toDelete = downloads.filter { $0.novelId == novelId }
        for download in toDelete {
            deleteDownload(download)
        }
    }
    
    // 清空所有下载
    func clearAllDownloads() {
        for download in downloads {
            deleteDownload(download)
        }
    }
    
    // 获取总下载大小
    func totalDownloadSize() -> Int64 {
        return downloads.reduce(0) { $0 + $1.fileSize }
    }
    
    // 格式化大小
    func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
    
    // 检查章节是否已下载
    func isDownloaded(novelId: String, chapterIndex: Int) -> Bool {
        return downloads.contains { $0.novelId == novelId && $0.chapterIndex == chapterIndex }
    }
}
