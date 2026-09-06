import Foundation

struct NovelSource: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let baseURL: String
    var enabled: Bool
    var searchPath: String?
}

class NovelSourceManager: ObservableObject {
    static let shared = NovelSourceManager()
    
    @Published var sources: [NovelSource] = []
    @Published var enabledSourceIds: Set<String> = []
    
    init() {
        loadSources()
    }
    
    func loadSources() {
        var list: [NovelSource] = []
        let s1 = NovelSource(id: "s1", name: "笔趣阁", baseURL: "https://www.biquge.co", enabled: true, searchPath: "/search.php?keyword=")
        let s2 = NovelSource(id: "s2", name: "笔趣阁5200", baseURL: "https://www.biquge5200.cc", enabled: true, searchPath: "/search.php?keyword=")
        let s3 = NovelSource(id: "s3", name: "新笔趣阁", baseURL: "https://www.xbiquge.la", enabled: true, searchPath: "/search.php?keyword=")
        let s4 = NovelSource(id: "s4", name: "书趣阁", baseURL: "https://www.shuquge.com", enabled: true, searchPath: "/search?keyword=")
        let s5 = NovelSource(id: "s5", name: "顶点小说", baseURL: "https://www.23wx.la", enabled: true, searchPath: "/search?keyword=")
        list = [s1, s2, s3, s4, s5]
        
        if let data = UserDefaults.standard.data(forKey: "novel.sources") {
            if let custom = try? JSONDecoder().decode([NovelSource].self, from: data) {
                list.append(contentsOf: custom)
            }
        }
        sources = list
        
        if let enabled = UserDefaults.standard.array(forKey: "novel.enabledSources") as? [String] {
            enabledSourceIds = Set(enabled)
        } else {
            enabledSourceIds = ["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11", "s12", "s13", "s14", "s15", "s16", "s17", "s18", "s19", "s20", "s21", "s22", "s23", "s24", "s25", "s26", "s27", "s28", "s29", "s30", "s31", "s32", "s33", "s34", "s35", "s36", "s37", "s38", "s39", "s40", "s41", "s42", "s43", "s44", "s45", "s46", "s47", "s48", "s49", "s50", "s51", "s52", "s53", "s54", "s55"]
        }
    }
    
    func saveEnabledSources() {
        UserDefaults.standard.set(Array(enabledSourceIds), forKey: "novel.enabledSources")
    }
    
    func toggleSource(_ id: String) {
        if enabledSourceIds.contains(id) {
            enabledSourceIds.remove(id)
        } else {
            enabledSourceIds.insert(id)
        }
        saveEnabledSources()
    }
    
    func enabledSources() -> [NovelSource] {
        var result: [NovelSource] = []
        for source in sources {
            if enabledSourceIds.contains(source.id) && !source.baseURL.isEmpty {
                result.append(source)
            }
        }
        return result
    }
    
    func addSource(name: String, baseURL: String) {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http") {
            url = "https://" + url
        }
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        
        let newSource = NovelSource(id: UUID().uuidString, name: name, baseURL: url, enabled: true, searchPath: "/search.php?keyword=")
        sources.append(newSource)
        enabledSourceIds.insert(newSource.id)
        saveCustomSources()
        saveEnabledSources()
    }
    
    // 从JSON文本导入书源（支持多种格式）
    func importFromJSON(_ jsonText: String) -> Int {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard let data = trimmed.data(using: .utf8) else { return 0 }
        
        var importedCount = 0
        
        // 格式1: 标准NovelSource数组
        if let array = try? JSONDecoder().decode([NovelSource].self, from: data) {
            for source in array {
                if !source.baseURL.isEmpty && !sources.contains(where: { $0.baseURL == source.baseURL }) {
                    let newSource = NovelSource(id: UUID().uuidString, name: source.name.isEmpty ? "未命名" : source.name, baseURL: source.baseURL, enabled: true, searchPath: source.searchPath ?? "/search.php?keyword=")
                    sources.append(newSource)
                    enabledSourceIds.insert(newSource.id)
                    importedCount += 1
                }
            }
            if importedCount > 0 {
                saveCustomSources()
                saveEnabledSources()
                return importedCount
            }
        }
        
        // 格式2: 单个NovelSource
        if let single = try? JSONDecoder().decode(NovelSource.self, from: data) {
            if !single.baseURL.isEmpty && !sources.contains(where: { $0.baseURL == single.baseURL }) {
                let newSource = NovelSource(id: UUID().uuidString, name: single.name.isEmpty ? "未命名" : single.name, baseURL: single.baseURL, enabled: true, searchPath: single.searchPath ?? "/search.php?keyword=")
                sources.append(newSource)
                enabledSourceIds.insert(newSource.id)
                saveCustomSources()
                saveEnabledSources()
                return 1
            }
        }
        
        // 格式3: 简单格式 [{name, url}] 或 [{title, baseUrl}] 或 单个对象
        if let jsonObj = try? JSONSerialization.jsonObject(with: data) {
            // 处理数组
            if let array = jsonObj as? [[String: Any]] {
                for item in array {
                    let name = (item["name"] as? String) ?? (item["title"] as? String) ?? (item["sourceName"] as? String) ?? "未命名"
                    let url = (item["baseURL"] as? String) ?? (item["url"] as? String) ?? (item["baseUrl"] as? String) ?? (item["link"] as? String) ?? (item["host"] as? String) ?? ""
                    if !url.isEmpty && !sources.contains(where: { $0.baseURL == url }) {
                        let newSource = NovelSource(id: UUID().uuidString, name: name, baseURL: url, enabled: true, searchPath: "/search.php?keyword=")
                        sources.append(newSource)
                        enabledSourceIds.insert(newSource.id)
                        importedCount += 1
                    }
                }
            } else if let item = jsonObj as? [String: Any] {
                let name = (item["name"] as? String) ?? (item["title"] as? String) ?? "未命名"
                let url = (item["baseURL"] as? String) ?? (item["url"] as? String) ?? (item["baseUrl"] as? String) ?? ""
                if !url.isEmpty && !sources.contains(where: { $0.baseURL == url }) {
                    let newSource = NovelSource(id: UUID().uuidString, name: name, baseURL: url, enabled: true, searchPath: "/search.php?keyword=")
                    sources.append(newSource)
                    enabledSourceIds.insert(newSource.id)
                    importedCount += 1
                }
            }
        }
        
        if importedCount > 0 {
            saveCustomSources()
            saveEnabledSources()
        }
        return importedCount
    }
    
    func removeSource(_ id: String) {
        sources.removeAll { $0.id == id }
        enabledSourceIds.remove(id)
        saveCustomSources()
        saveEnabledSources()
    }
    
    private func saveCustomSources() {
        let builtInIds = ["s1", "s2", "s3", "s4", "s5"]
        var custom: [NovelSource] = []
        for source in sources {
            if !builtInIds.contains(source.id) {
                custom.append(source)
            }
        }
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: "novel.sources")
        }
    }
}
