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
        AudiobookSource(id: "ysx8", name: "有声下吧", baseURL: "https://www.ysx8.net", enabled: true),
        AudiobookSource(id: "tingshu", name: "听书吧", baseURL: "https://www.tingshu8.com", enabled: true),
        AudiobookSource(id: "pingshu", name: "我听评书", baseURL: "https://www.5tps.com", enabled: true),
        AudiobookSource(id: "xiangsheng", name: "相声坛子", baseURL: "https://www.pingshu8.com", enabled: true),
        AudiobookSource(id: "haiyang", name: "海洋听书", baseURL: "https://www.hyting.com", enabled: true),
        AudiobookSource(id: "huayin", name: "华音网", baseURL: "https://www.huayinyue.com", enabled: false),
        AudiobookSource(id: "jingting", name: "静听网", baseURL: "https://www.jting.net", enabled: true),
        AudiobookSource(id: "aitingshu", name: "爱听书", baseURL: "https://www.aitingshu.com", enabled: true),
        AudiobookSource(id: "tianfang", name: "天方听书", baseURL: "https://www.tingbook.com", enabled: true),
        AudiobookSource(id: "520ting", name: "520听书", baseURL: "https://www.520tingshu.com", enabled: true),
        AudiobookSource(id: "kuyin", name: "酷音听书", baseURL: "https://www.kuyin.com", enabled: false),
        AudiobookSource(id: "yousheng", name: "有声听书", baseURL: "https://www.yousheng.com", enabled: true),
        AudiobookSource(id: "ting8", name: "听8有声", baseURL: "https://www.ting89.com", enabled: true),
        AudiobookSource(id: "aating", name: "AA听书", baseURL: "https://www.aating.com", enabled: true),
    ]
    
    struct AudiobookSource: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let baseURL: String
        var enabled: Bool
    }
}
