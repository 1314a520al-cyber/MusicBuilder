import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published var books: [Book] = []
    @Published var records: [WritingRecord] = []
    @Published var inspirations: [Inspiration] = []
    @Published var aiSettings: AISettings = AISettings()
    @Published var appSettings: AppSettings = AppSettings()
    @Published var aiLogs: [AICallLog] = []
    @Published var aiConversations: [UUID: [AIMessage]] = [:]

    private let fileManager = FileManager.default
    private var dataDir: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EasyWriting", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() { load() }

    // MARK: - 持久化
    private func fileURL(_ name: String) -> URL {
        dataDir.appendingPathComponent(name)
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(books).write(to: fileURL("books.json"))
            try encoder.encode(records).write(to: fileURL("records.json"))
            try encoder.encode(inspirations).write(to: fileURL("inspirations.json"))
            try encoder.encode(aiSettings).write(to: fileURL("ai_settings.json"))
            try encoder.encode(appSettings).write(to: fileURL("app_settings.json"))
            try encoder.encode(aiLogs).write(to: fileURL("ai_logs.json"))
        } catch {
            print("保存失败: \(error)")
        }
    }

    func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            if let data = try? Data(contentsOf: fileURL("books.json")) {
                books = try decoder.decode([Book].self, from: data)
            }
            if let data = try? Data(contentsOf: fileURL("records.json")) {
                records = try decoder.decode([WritingRecord].self, from: data)
            }
            if let data = try? Data(contentsOf: fileURL("inspirations.json")) {
                inspirations = try decoder.decode([Inspiration].self, from: data)
            }
            if let data = try? Data(contentsOf: fileURL("ai_settings.json")) {
                aiSettings = try decoder.decode(AISettings.self, from: data)
            }
            if let data = try? Data(contentsOf: fileURL("app_settings.json")) {
                appSettings = try decoder.decode(AppSettings.self, from: data)
            }
            if let data = try? Data(contentsOf: fileURL("ai_logs.json")) {
                aiLogs = try decoder.decode([AICallLog].self, from: data)
            }
        } catch {
            print("加载失败: \(error)")
        }
    }

    // MARK: - 作品操作
    func addBook(_ book: Book) {
        books.append(book)
        save()
    }

    func updateBook(_ book: Book) {
        if let idx = books.firstIndex(where: { $0.id == book.id }) {
            var b = book
            b.updatedAt = Date()
            books[idx] = b
            save()
        }
    }

    func deleteBook(_ id: UUID) {
        if let idx = books.firstIndex(where: { $0.id == id }) {
            books[idx].isDeleted = true
            save()
        }
    }

    func permanentDeleteBook(_ id: UUID) {
        books.removeAll { $0.id == id }
        save()
    }

    func restoreBook(_ id: UUID) {
        if let idx = books.firstIndex(where: { $0.id == id }) {
            books[idx].isDeleted = false
            save()
        }
    }

    var activeBooks: [Book] { books.filter { !$0.isDeleted }.sorted { $0.updatedAt > $1.updatedAt } }
    var deletedBooks: [Book] { books.filter { $0.isDeleted } }

    // MARK: - 章节操作
    func addChapter(to bookId: UUID, title: String) -> Chapter? {
        guard let idx = books.firstIndex(where: { $0.id == bookId }) else { return nil }
        let chapter = Chapter(title: title)
        books[idx].chapters.append(chapter)
        books[idx].updatedAt = Date()
        save()
        return chapter
    }

    func updateChapter(in bookId: UUID, _ chapter: Chapter) {
        guard let bidx = books.firstIndex(where: { $0.id == bookId }) else { return }
        if let cidx = books[bidx].chapters.firstIndex(where: { $0.id == chapter.id }) {
            var c = chapter
            c.updatedAt = Date()
            // 自动保存历史版本（每5分钟一个快照）
            if let last = c.history.last, Date().timeIntervalSince(last.date) > 300 {
                c.history.append(ChapterSnapshot(content: c.content, date: Date()))
                if c.history.count > 50 { c.history.removeFirst() }
            } else if c.history.isEmpty {
                c.history.append(ChapterSnapshot(content: c.content, date: Date()))
            }
            books[bidx].chapters[cidx] = c
            books[bidx].updatedAt = Date()
            save()
        }
    }

    func deleteChapter(from bookId: UUID, _ chapterId: UUID) {
        guard let bidx = books.firstIndex(where: { $0.id == bookId }) else { return }
        books[bidx].chapters.removeAll { $0.id == chapterId }
        books[bidx].updatedAt = Date()
        save()
    }

    func moveChapter(in bookId: UUID, from source: IndexSet, to destination: Int) {
        guard let bidx = books.firstIndex(where: { $0.id == bookId }) else { return }
        books[bidx].chapters.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - 码字记录
    func addRecord(_ record: WritingRecord) {
        records.append(record)
        save()
    }

    var todayWords: Int {
        let cal = Calendar.current
        return records.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.wordsWritten }
    }

    var todayAIWords: Int {
        let cal = Calendar.current
        return records.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.aiWords }
    }

    var streakDays: Int {
        let cal = Calendar.current
        var streak = 0
        var date = Date()
        while true {
            let hasRecord = records.contains { cal.isDate($0.date, inSameDayAs: date) && $0.wordsWritten > 0 }
            if hasRecord {
                streak += 1
                date = cal.date(byAdding: .day, value: -1, to: date)!
            } else {
                if streak == 0 && cal.isDateInToday(date) {
                    date = cal.date(byAdding: .day, value: -1, to: date)!
                    continue
                }
                break
            }
        }
        return streak
    }

    func wordsForLastDays(_ days: Int) -> [(date: Date, words: Int, aiWords: Int)] {
        let cal = Calendar.current
        var result: [(Date, Int, Int)] = []
        for i in (0..<days).reversed() {
            let date = cal.date(byAdding: .day, value: -i, to: Date())!
            let dayRecords = records.filter { cal.isDate($0.date, inSameDayAs: date) }
            let words = dayRecords.reduce(0) { $0 + $1.wordsWritten }
            let aiWords = dayRecords.reduce(0) { $0 + $1.aiWords }
            result.append((date, words, aiWords))
        }
        return result
    }

    // MARK: - 灵感
    func addInspiration(_ content: String, tag: String = "") {
        inspirations.insert(Inspiration(content: content, tag: tag), at: 0)
        save()
    }

    func deleteInspiration(_ id: UUID) {
        inspirations.removeAll { $0.id == id }
        save()
    }

    func togglePinInspiration(_ id: UUID) {
        if let idx = inspirations.firstIndex(where: { $0.id == id }) {
            inspirations[idx].isPinned.toggle()
            inspirations.sort { $0.isPinned && !$1.isPinned }
            save()
        }
    }

    // MARK: - AI 日志
    func addAILog(_ log: AICallLog) {
        aiLogs.insert(log, at: 0)
        if aiLogs.count > 200 { aiLogs.removeLast() }
        save()
    }

    // MARK: - 导出
    func exportBookAsTXT(_ book: Book) -> URL? {
        var text = "\(book.title)\n\n"
        if !book.author.isEmpty { text += "作者：\(book.author)\n\n" }
        for chapter in book.chapters {
            text += "\n\(chapter.title)\n\n\(chapter.content)\n\n"
        }
        let url = fileManager.temporaryDirectory.appendingPathComponent("\(book.title).txt")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch { return nil }
    }

    func exportBookAsJSON(_ book: Book) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(book)
            let url = fileManager.temporaryDirectory.appendingPathComponent("\(book.title).json")
            try data.write(to: url)
            return url
        } catch { return nil }
    }

    // MARK: - 存储管理
    func storageSize() -> (total: Int64, data: Int64, cache: Int64) {
        let fm = FileManager.default
        var total: Int64 = 0
        var dataSize: Int64 = 0
        var cacheSize: Int64 = 0

        // 数据目录
        if let enumerator = fm.enumerator(at: dataDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    dataSize += Int64(size)
                }
            }
        }

        // 缓存目录
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        if let enumerator = fm.enumerator(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    cacheSize += Int64(size)
                }
            }
        }

        // 临时目录
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
        if let enumerator = fm.enumerator(at: tmpDir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    cacheSize += Int64(size)
                }
            }
        }

        total = dataSize + cacheSize
        return (total, dataSize, cacheSize)
    }

    func clearCache() {
        let fm = FileManager.default
        // 清除缓存目录
        let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        if let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fm.removeItem(at: file)
            }
        }
        // 清除临时目录
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
        if let files = try? fm.contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fm.removeItem(at: file)
            }
        }
    }

    func resetAllData() {
        books = []
        records = []
        inspirations = []
        aiSettings = AISettings()
        appSettings = AppSettings()
        aiLogs = []
        aiConversations = [:]
        // 删除数据目录所有文件
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: dataDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fm.removeItem(at: file)
            }
        }
        clearCache()
        save()
    }

    func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
    }

    // MARK: - 备份
    func backupAll() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        do {
            var backup: [String: Any] = [
                "backupDate": Date().iso8601
            ]
            if let d = try? encoder.encode(books) { backup["books"] = try JSONSerialization.jsonObject(with: d) }
            if let d = try? encoder.encode(records) { backup["records"] = try JSONSerialization.jsonObject(with: d) }
            if let d = try? encoder.encode(inspirations) { backup["inspirations"] = try JSONSerialization.jsonObject(with: d) }
            if let d = try? encoder.encode(aiSettings) { backup["aiSettings"] = try JSONSerialization.jsonObject(with: d) }
            if let d = try? encoder.encode(appSettings) { backup["appSettings"] = try JSONSerialization.jsonObject(with: d) }
            let data = try JSONSerialization.data(withJSONObject: backup, options: .prettyPrinted)
            let url = fileManager.temporaryDirectory.appendingPathComponent("易创备份_\(Date().timeIntervalSince1970).json")
            try data.write(to: url)
            return url
        } catch { return nil }
    }
}

extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
