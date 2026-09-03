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
        ComicSource(id: "manhuaren", name: "漫画人", baseURL: "https://www.manhuaren.com", enabled: true),
        ComicSource(id: "manhuadao", name: "漫画岛", baseURL: "https://www.manhuadao.cn", enabled: true),
        ComicSource(id: "chuixue", name: "吹雪漫画", baseURL: "https://www.chuixue.com", enabled: true),
        ComicSource(id: "hanhan", name: "汗汗漫画", baseURL: "https://www.hhcomic.com", enabled: true),
        ComicSource(id: "jisu", name: "极速漫画", baseURL: "https://www.1kkk.com", enabled: true),
        ComicSource(id: "bengou", name: "笨狗漫画", baseURL: "https://www.bengou.com", enabled: true),
        ComicSource(id: "tubenben", name: "兔笨笨", baseURL: "https://www.tubenben.com", enabled: false),
        ComicSource(id: "xinxin", name: "新新漫画", baseURL: "https://www.733.cc", enabled: true),
        ComicSource(id: "dm5", name: "动漫屋", baseURL: "https://www.dm5.com", enabled: true),
        ComicSource(id: "comicui", name: "漫画堆", baseURL: "https://www.177pic.com", enabled: true),
        ComicSource(id: "gufeng", name: "古风漫画", baseURL: "https://www.gufengmh.com", enabled: true),
        ComicSource(id: "36mh", name: "36漫画", baseURL: "https://www.36mh.com", enabled: true),
        ComicSource(id: "6mh", name: "6漫画", baseURL: "https://www.6mh.com", enabled: true),
        ComicSource(id: "mhcdn", name: "漫画CDN", baseURL: "https://www.mhcdn.net", enabled: false),
        ComicSource(id: "manhuakan", name: "漫画看", baseURL: "https://www.manhuakan.com", enabled: true),
    ]
    
    struct ComicSource: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let baseURL: String
        var enabled: Bool
    }
}
