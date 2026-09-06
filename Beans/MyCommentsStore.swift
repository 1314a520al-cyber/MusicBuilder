import Foundation

/// 用户发送过的评论（本地持久化）
struct SentComment: Codable, Identifiable, Equatable {
    let id: String
    let songID: Int
    let songName: String
    let content: String
    let time: Date
    let platform: String // netease / qq / kugou
}

final class MyCommentsStore: ObservableObject {
    static let shared = MyCommentsStore()
    @Published private(set) var comments: [SentComment] = []

    private let key = "my_sent_comments_v1"

    private init() { load() }

    func add(songID: Int, songName: String, content: String, platform: String) {
        let c = SentComment(id: UUID().uuidString, songID: songID, songName: songName, content: content, time: Date(), platform: platform)
        comments.insert(c, at: 0)
        if comments.count > 200 { comments = Array(comments.prefix(200)) }
        save()
    }

    func commentsFor(songID: Int) -> [SentComment] {
        comments.filter { $0.songID == songID }
    }

    func remove(_ c: SentComment) {
        comments.removeAll { $0.id == c.id }
        save()
    }

    func clear() {
        comments.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(comments) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([SentComment].self, from: data) else { return }
        comments = arr
    }
}
