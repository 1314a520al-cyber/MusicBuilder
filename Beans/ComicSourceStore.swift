import Foundation

class ComicSourceStore: ObservableObject {
    static let shared = ComicSourceStore()
    @Published var sources: [ComicSource] = [
        ComicSource(id: "dmzj", name: "动漫之家", baseURL: "https://www.dmzj.com", enabled: true),
        ComicSource(id: "tencent", name: "腾讯动漫", baseURL: "https://ac.qq.com", enabled: true),
        ComicSource(id: "kuaikan", name: "快看漫画", baseURL: "https://www.kuaikanmanhua.com", enabled: true),
        ComicSource(id: "bilibili", name: "哔哩哔哩漫画", baseURL: "https://manga.bilibili.com", enabled: true),
        ComicSource(id: "u17", name: "有妖气", baseURL: "https://www.u17.com", enabled: true),
        ComicSource(id: "manhuagui", name: "漫画柜", baseURL: "https://www.manhuagui.com", enabled: true),
        ComicSource(id: "manhuadb", name: "漫画DB", baseURL: "https://www.manhuadb.com", enabled: true),
        ComicSource(id: "kanman", name: "看漫画", baseURL: "https://www.kanman.com", enabled: false),
        ComicSource(id: "52manhua", name: "52漫画", baseURL: "https://www.52manhua.com", enabled: true),
        ComicSource(id: "mh1234", name: "漫画1234", baseURL: "https://www.mh1234.com", enabled: false),
        ComicSource(id: "copymanga", name: "拷贝漫画", baseURL: "https://www.copymanga.site", enabled: true),
        ComicSource(id: "jmcomic", name: "禁漫天堂", baseURL: "https://18comic.vip", enabled: false),
    ]
    
    struct ComicSource: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let baseURL: String
        var enabled: Bool
    }
}
