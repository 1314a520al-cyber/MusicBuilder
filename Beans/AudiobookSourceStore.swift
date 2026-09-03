import Foundation

class AudiobookSourceStore: ObservableObject {
    static let shared = AudiobookSourceStore()
    @Published var sources: [AudiobookSource] = [
        AudiobookSource(id: "ximalaya", name: "喜马拉雅", baseURL: "https://www.ximalaya.com", enabled: true),
        AudiobookSource(id: "qingting", name: "蜻蜓FM", baseURL: "https://www.qingting.fm", enabled: true),
        AudiobookSource(id: "lrts", name: "懒人听书", baseURL: "https://www.lrts.me", enabled: true),
        AudiobookSource(id: "kuwo", name: "酷我听书", baseURL: "https://ting.kuwo.cn", enabled: true),
        AudiobookSource(id: "tingchina", name: "听中国", baseURL: "https://www.tingchina.com", enabled: true),
        AudiobookSource(id: "kugou", name: "酷狗听书", baseURL: "https://www.kugou.com/ting", enabled: false),
        AudiobookSource(id: "missevan", name: "猫耳FM", baseURL: "https://www.missevan.com", enabled: true),
        AudiobookSource(id: "pear", name: "梨视频有声", baseURL: "https://www.pearvideo.com", enabled: false),
        AudiobookSource(id: "5tps", name: "5tps听书", baseURL: "https://www.5tps.com", enabled: true),
        AudiobookSource(id: "ysxs", name: "有声小说网", baseURL: "https://www.ysxs.com", enabled: true),
        AudiobookSource(id: "jianggushi", name: "讲故事", baseURL: "https://www.jianggushi.com", enabled: false),
        AudiobookSource(id: "kting", name: "酷听听书", baseURL: "https://www.kting.cn", enabled: true),
    ]
    
    struct AudiobookSource: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let baseURL: String
        var enabled: Bool
    }
}
