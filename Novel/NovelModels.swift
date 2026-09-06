import Foundation

// 小说
struct Novel: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let coverURL: String?
    let intro: String?
    let sourceId: String
    let bookUrl: String
    var lastChapter: String?
    var updateTime: String?
    var category: String?
    var status: String? // 连载/完结
    
    enum CodingKeys: String, CodingKey {
        case id, title, author, coverURL, intro, sourceId, bookUrl, lastChapter, updateTime, category, status
    }
}

// 章节
struct NovelChapter: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let url: String
    let index: Int
}

// 章节内容
struct ChapterContent: Codable {
    let title: String
    let content: String
    let prevUrl: String?
    let nextUrl: String?
}

// 阅读记录
struct ReadingRecord: Codable {
    let novelId: String
    let chapterIndex: Int
    let progress: Double
    let lastReadTime: Date
}

// 阅读页面Sheet数据
struct ReaderSheetData: Identifiable {
    let id = UUID()
    let novel: Novel
    let chapters: [NovelChapter]
    let startIndex: Int
}
