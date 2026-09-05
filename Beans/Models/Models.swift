import Foundation

// MARK: - 作品
struct Book: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var author: String = ""
    var coverData: Data? = nil
    var category: String = "未分类"
    var description: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var chapters: [Chapter] = []
    var outline: String = ""
    var characters: [Character] = []
    var settings: [WorldSetting] = []
    var timeline: [TimelineEvent] = []
    var dailyTarget: Int = 4000
    var totalWords: Int { chapters.reduce(0) { $0 + $1.wordCount } }

    static func == (lhs: Book, rhs: Book) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - 章节
struct Chapter: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDraft: Bool = false
    var wordCount: Int { content.count }
    var history: [ChapterSnapshot] = []

    static func == (lhs: Chapter, rhs: Chapter) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ChapterSnapshot: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var content: String
    var date: Date
    var wordCount: Int { content.count }
}

// MARK: - 角色
struct Character: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var role: String = ""
    var description: String = ""
    var avatarData: Data? = nil
    var relations: [String] = []
}

// MARK: - 设定
struct WorldSetting: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String = ""
    var category: String = "世界观"
}

// MARK: - 时间线
struct TimelineEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: String
    var event: String
    var description: String = ""
}

// MARK: - 码字记录
struct WritingRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var bookId: UUID
    var chapterId: UUID?
    var wordsWritten: Int
    var aiWords: Int = 0
    var duration: TimeInterval = 0
}

// MARK: - 灵感
struct Inspiration: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var content: String
    var createdAt: Date = Date()
    var tag: String = ""
    var isPinned: Bool = false
}

// MARK: - AI 设置
struct AISettings: Codable {
    var apiKey: String = ""
    var baseURL: String = "https://api.deepseek.com"
    var model: String = "deepseek-chat"
    var temperature: Double = 0.7
    var maxTokens: Int = 4096
    var systemPrompt: String = "你是一个专业的网文写作助手，擅长剧情设计、人物塑造和文字润色。"
    var isEnabled: Bool { !apiKey.isEmpty }
}

// MARK: - 应用设置
struct AppSettings: Codable {
    var theme: String = "无界通透"
    var fontSize: Double = 17
    var lineHeight: Double = 1.8
    var textColor: String = "#1a1a1a"
    var bgColor: String = "#f5f5f0"
    var typingSound: String = "静音"
    var typingEffect: String = "无"
    var autoSaveInterval: Double = 160
    var showWordCount: Bool = true
    var focusMode: Bool = false
    var dailyTarget: Int = 4000
    var sensitiveWords: [String] = []
}

// MARK: - AI 对话
struct AIMessage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var role: String // user / assistant / system
    var content: String
    var date: Date = Date()
}

// MARK: - AI 调用记录
struct AICallLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var scenario: String
    var inputWords: Int
    var outputWords: Int
    var tokens: Int
    var success: Bool
    var errorMessage: String?
}


// MARK: - 日期格式化
extension Date {
    var formattedDateTime: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: self)
    }
    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: self)
    }
}
