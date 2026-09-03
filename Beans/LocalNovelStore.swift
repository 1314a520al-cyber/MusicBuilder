import Foundation

class LocalNovelStore: ObservableObject {
    static let shared = LocalNovelStore()
    @Published var novels: [LocalNovel] = []
    
    private var novelsDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalNovels", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private init() { load() }
    
    struct LocalNovel: Identifiable, Codable, Hashable {
        let id: String
        let title: String
        let author: String
        let intro: String
        let wordCount: Int
        let importDate: Date
        var chapters: [LocalNovelChapter]
        var lastReadChapter: Int
        var lastReadOffset: Int
    }
    
    struct LocalNovelChapter: Identifiable, Codable, Hashable {
        let id: String
        let title: String
        let content: String
    }
    
    func load() {
        let file = novelsDir.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([LocalNovel].self, from: data) else {
            novels = []
            return
        }
        novels = decoded
    }
    
    func save() {
        let file = novelsDir.appendingPathComponent("index.json")
        if let data = try? JSONEncoder().encode(novels) {
            try? data.write(to: file)
        }
    }
    
    func importNovel(from url: URL) async throws -> LocalNovel {
        let id = UUID().uuidString
        let ext = url.pathExtension.lowercased()
        
        var content = ""
        if ext == "txt" {
            // 读取TXT，尝试多种编码
            if let data = try? Data(contentsOf: url) {
                let gbk = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
                let big5 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue)))
                for encoding in [.utf8, gbk, big5] {
                    if let str = String(data: data, encoding: encoding) {
                        content = str
                        break
                    }
                }
            }
        } else {
            content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        
        guard !content.isEmpty else {
            throw NSError(domain: "LocalNovel", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取文件内容"])
        }
        
        // 按章节分割（匹配常见章节标题格式）
        let chapters = parseChapters(from: content)
        let title = url.deletingPathExtension().lastPathComponent
        let wordCount = content.count
        
        let novel = LocalNovel(
            id: id,
            title: title,
            author: "本地导入",
            intro: "本地导入小说，共\(chapters.count)章，约\(wordCount)字",
            wordCount: wordCount,
            importDate: Date(),
            chapters: chapters,
            lastReadChapter: 0,
            lastReadOffset: 0
        )
        
        // 保存原文
        let fileURL = novelsDir.appendingPathComponent("\(id).txt")
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        DispatchQueue.main.async {
            self.novels.insert(novel, at: 0)
            self.save()
        }
        return novel
    }
    
    private func parseChapters(from text: String) -> [LocalNovelChapter] {
        let pattern = "(?m)^\\s*(第[一二三四五六七八九十百千万零〇两\\d]+[章节回卷集部篇][^\\n]*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [LocalNovelChapter(id: UUID().uuidString, title: "全文", content: text)]
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard matches.count > 1 else {
            return [LocalNovelChapter(id: UUID().uuidString, title: "全文", content: text)]
        }
        
        var chapters: [LocalNovelChapter] = []
        for (i, match) in matches.enumerated() {
            let start = Range(match.range, in: text)!.lowerBound
            let end = (i + 1 < matches.count) ? Range(matches[i+1].range, in: text)!.lowerBound : text.endIndex
            let chapterText = String(text[start..<end])
            let title = String(text[start..<Range(match.range, in: text)!.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            chapters.append(LocalNovelChapter(id: UUID().uuidString, title: title, content: chapterText))
        }
        return chapters
    }
    
    func deleteNovel(_ novel: LocalNovel) {
        let file = novelsDir.appendingPathComponent("\(novel.id).txt")
        try? FileManager.default.removeItem(at: file)
        novels.removeAll { $0.id == novel.id }
        save()
    }
    
    func updateProgress(novelId: String, chapter: Int, offset: Int) {
        guard let index = novels.firstIndex(where: { $0.id == novelId }) else { return }
        novels[index].lastReadChapter = chapter
        novels[index].lastReadOffset = offset
        save()
    }
}
