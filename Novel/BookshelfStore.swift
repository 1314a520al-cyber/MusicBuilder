import Foundation
import SwiftUI

class BookshelfStore: ObservableObject {
    static let shared = BookshelfStore()
    
    @Published var books: [Novel] = []
    @Published var readingRecords: [String: ReadingRecord] = [:]
    
    init() {
        load()
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: "bookshelf.books"),
           let decoded = try? JSONDecoder().decode([Novel].self, from: data) {
            books = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "bookshelf.records"),
           let decoded = try? JSONDecoder().decode([String: ReadingRecord].self, from: data) {
            readingRecords = decoded
        }
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(data, forKey: "bookshelf.books")
        }
        if let data = try? JSONEncoder().encode(readingRecords) {
            UserDefaults.standard.set(data, forKey: "bookshelf.records")
        }
    }
    
    func addBook(_ novel: Novel) {
        if !books.contains(where: { $0.id == novel.id }) {
            books.insert(novel, at: 0)
            save()
        }
    }
    
    func removeBook(_ novel: Novel) {
        books.removeAll { $0.id == novel.id }
        readingRecords.removeValue(forKey: novel.id)
        save()
    }
    
    func isInShelf(_ novel: Novel) -> Bool {
        return books.contains { $0.id == novel.id }
    }
    
    func updateProgress(novelId: String, chapterIndex: Int, progress: Double) {
        readingRecords[novelId] = ReadingRecord(novelId: novelId, chapterIndex: chapterIndex, progress: progress, lastReadTime: Date())
        save()
    }
    
    func getProgress(novelId: String) -> ReadingRecord? {
        return readingRecords[novelId]
    }
}
