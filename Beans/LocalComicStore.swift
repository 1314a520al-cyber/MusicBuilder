import Foundation
import UIKit

class LocalComicStore: ObservableObject {
    static let shared = LocalComicStore()
    @Published var comics: [LocalComic] = []
    
    private var comicsDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalComics", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private init() { load() }
    
    struct LocalComic: Identifiable, Codable, Hashable {
        let id: String
        let title: String
        let coverPath: String
        let pageCount: Int
        let importDate: Date
        var chapters: [LocalChapter]
    }
    
    struct LocalChapter: Identifiable, Codable, Hashable {
        let id: String
        let title: String
        var imagePaths: [String]
    }
    
    func load() {
        let file = comicsDir.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([LocalComic].self, from: data) else {
            comics = []
            return
        }
        comics = decoded
    }
    
    func save() {
        let file = comicsDir.appendingPathComponent("index.json")
        if let data = try? JSONEncoder().encode(comics) {
            try? data.write(to: file)
        }
    }
    
    func importComic(from url: URL) async throws -> LocalComic {
        let id = UUID().uuidString
        let comicDir = comicsDir.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: comicDir, withIntermediateDirectories: true)
        
        var imagePaths: [String] = []
        
        // 支持单张或多张图片导入
        let ext = url.pathExtension.lowercased()
        if ["jpg","jpeg","png","webp","gif","bmp"].contains(ext) {
            // 单张图片
            let dest = comicDir.appendingPathComponent("page_0001.\(ext)")
            try? FileManager.default.copyItem(at: url, to: dest)
            imagePaths.append(dest.lastPathComponent)
        }
        
        guard !imagePaths.isEmpty else {
            try? FileManager.default.removeItem(at: comicDir)
            throw NSError(domain: "LocalComic", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到图片文件"])
        }
        
        let coverPath = comicDir.appendingPathComponent(imagePaths[0]).path
        let title = url.deletingPathExtension().lastPathComponent
        let chapter = LocalChapter(id: UUID().uuidString, title: "第1话", imagePaths: imagePaths)
        let comic = LocalComic(id: id, title: title, coverPath: coverPath, pageCount: imagePaths.count, importDate: Date(), chapters: [chapter])
        
        DispatchQueue.main.async {
            self.comics.insert(comic, at: 0)
            self.save()
        }
        return comic
    }
    
    func deleteComic(_ comic: LocalComic) {
        let dir = comicsDir.appendingPathComponent(comic.id)
        try? FileManager.default.removeItem(at: dir)
        comics.removeAll { $0.id == comic.id }
        save()
    }
    
    func imageURL(for comic: LocalComic, pageIndex: Int) -> URL? {
        guard let chapter = comic.chapters.first, pageIndex < chapter.imagePaths.count else { return nil }
        let dir = comicsDir.appendingPathComponent(comic.id)
        return dir.appendingPathComponent(chapter.imagePaths[pageIndex])
    }
}
