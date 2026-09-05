import Foundation
/// 灰色歌曲 / VIP 试听解锁：使用内置预设 + 用户自定义音乐源。
/// 由 PlayerManager 在网易云 / QQ / 酷狗无完整 URL 时自动调用，
/// 会并发请求所有可用音源，最快返回可播放地址的音源胜出——即“播放自动识别音乐源”。
enum UnblockService {
    struct Resolved {
        let url: URL
        let source: String
        var sourceTitle: String { source }
    }
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 7
        config.timeoutIntervalForResource = 12
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    /// 入口：并发尝试可用于当前平台的音源，返回第一个可用地址。
    static func resolve(
        name: String,
        artists: String,
        neteaseID: Int,
        songSource: SongSource = .netease,
        qqMid: String? = nil,
        kugouID: String? = nil,
        strict: Bool = false
    ) async -> Resolved? {
        let hasSongIdentity = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !artists.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasSongIdentity else { return nil }
        // 仅使用已启用、模板非空、且需要卡密时已填写卡密的音源
        let sources = UnblockSourceStore.shared.presetSources
            .filter {
                $0.enabled
                && !$0.template.isEmpty
                && !$0.missingKey
                && canUse(source: $0, songSource: songSource, neteaseID: neteaseID, qqMid: qqMid, kugouID: kugouID)
            }
        guard !sources.isEmpty else { return nil }
        // 多个音源最终可能访问同一接口，只保留每个请求指纹的第一个，避免请求风暴。
        var seen = Set<String>()
        let uniqueSources = sources.filter { seen.insert(requestFingerprint(for: $0)).inserted }
        // 慢源/失效源不要拖住播放：全部候选一起请求，最快命中的播放地址直接返回。
        return await withTaskGroup(of: Resolved?.self) { group in
            for source in uniqueSources {
                group.addTask {
                    return await sourceRequest(
                        source: source,
                        name: name,
                        artists: artists,
                        neteaseID: neteaseID,
                        songSource: songSource,
                        qqMid: qqMid,
                        kugouID: kugouID
                    )
                }
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
    }
    /// 该音源能否用于当前歌曲：
    /// - 若音源限定了平台（headers.source），平台必须一致；
    /// - 依赖歌曲 ID（模板含 {id} 或内置预设）时，必须具备对应平台 ID；
    /// - 纯关键词/曲名音源（自定义且模板不含 {id}）只需要曲名即可参与。
    private static func canUse(source: ThirdPartySource, songSource: SongSource, neteaseID: Int, qqMid: String?, kugouID: String?) -> Bool {
        let expectedProvider = providerCode(for: songSource)
        if let provider = source.headers["source"], !provider.isEmpty, provider != expectedProvider {
            return false
        }
        let needsID = source.isPreset || source.template.contains("{id}")
        guard needsID else { return true }
        if songSource == .qq {
            return qqMid?.isEmpty == false
        }
        if songSource == .kugou {
            return kugouID?.isEmpty == false
        }
        return neteaseID > 0
    }
    private static func sourceRequest(
        source: ThirdPartySource,
        name: String,
        artists: String,
        neteaseID: Int,
        songSource: SongSource,
        qqMid: String?,
        kugouID: String?
    ) async -> Resolved? {
        guard !source.template.isEmpty else { return nil }
        // 需要卡密但没填：直接跳过
        if source.missingKey { return nil }
        let expectedProvider = providerCode(for: songSource)
        if let provider = source.headers["source"], !provider.isEmpty, provider != expectedProvider {
            return nil
        }
        let needsID = source.isPreset || source.template.contains("{id}")
        var songID = ""
        if needsID {
            switch songSource {
            case .netease where neteaseID > 0:
                songID = String(neteaseID)
            case .qq:
                guard let qqMid, !qqMid.isEmpty else { return nil }
                songID = qqMid
            case .kugou:
                guard let kugouID, !kugouID.isEmpty else { return nil }
                songID = kugouID
            default:
                return nil
            }
        }
        let keyword = ([name, artists].filter { !$0.isEmpty }).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var urlString = source.template
        urlString = urlString.replacingOccurrences(of: "{id}", with: songID)
        urlString = urlString.replacingOccurrences(of: "{source}", with: expectedProvider)
        urlString = urlString.replacingOccurrences(of: "{quality}", with: source.headers["quality"] ?? "320k")
        urlString = urlString.replacingOccurrences(of: "{name}", with: urlEncoded(name))
        urlString = urlString.replacingOccurrences(of: "{keyword}", with: urlEncoded(keyword))
        urlString = urlString.replacingOccurrences(of: "{artist}", with: urlEncoded(artists))
        urlString = urlString.replacingOccurrences(of: "{key}", with: urlEncoded(source.cardKey))
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 7
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Music-Source/1.0", forHTTPHeaderField: "User-Agent")
        // 内置预设使用 headers.apiKey；自定义音源的卡密在未显式指定 apiKey 时走 X-API-Key
        if let apiKey = source.headers["apiKey"], !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        } else if !source.cardKey.isEmpty {
            request.setValue(source.cardKey, forHTTPHeaderField: "X-API-Key")
            request.setValue(source.cardKey, forHTTPHeaderField: "Authorization")
        }
        let metadataKeys: Set<String> = ["source", "quality", "br", "apiKey"]
        for (key, value) in source.headers where !metadataKeys.contains(key) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            BeansLogger.shared.log("音源请求失败：\(source.name) \(error.localizedDescription)", level: .debug)
            return nil
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            BeansLogger.shared.log("音源 HTTP 失败：\(source.name) 状态=\(status)", level: .debug)
            return nil
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            BeansLogger.shared.log("音源响应格式错误：\(source.name)", level: .debug)
            return nil
        }
        if let code = responseCode(from: obj), code != 200 {
            let message = obj["message"] as? String ?? obj["msg"] as? String ?? "code=\(code)"
            BeansLogger.shared.log("音源返回失败：\(source.name) \(message)", level: .debug)
            return nil
        }
        guard let value = valueAtAnyPath(obj, source.urlPath),
              let resolvedURL = value as? String, !resolvedURL.isEmpty,
              let playURL = URL(string: resolvedURL) else {
            BeansLogger.shared.log("音源响应中没有播放地址：\(source.name)", level: .debug)
            return nil
        }
        BeansLogger.shared.log("音源命中：\(source.name) 平台=\(expectedProvider)", level: .info)
        return Resolved(url: playURL, source: source.name)
    }
    private static func requestFingerprint(for source: ThirdPartySource) -> String {
        let headers = source.headers
            .filter { $0.key != "source" }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        return "\(source.template)|\(source.urlPath)|\(headers)|\(source.cardKey)"
    }
    private static func responseCode(from object: [String: Any]) -> Int? {
        if let code = object["code"] as? Int {
            return code
        }
        if let code = object["code"] as? NSNumber {
            return code.intValue
        }
        if let code = object["code"] as? String {
            return Int(code)
        }
        return nil
    }
    private static func providerCode(for source: SongSource) -> String {
        switch source {
        case .netease: return "wy"
        case .qq: return "tx"
        case .kugou: return "kg"
        }
    }
    /// 多个点分路径取值：data.music|data.url|url。
    private static func valueAtAnyPath(_ obj: Any, _ paths: String) -> Any? {
        for path in paths.split(separator: "|") {
            if let value = valueAtPath(obj, String(path)) {
                return value
            }
        }
        return nil
    }
    /// 点分路径取值：url / data.url / data.audioUrl ...
    private static func valueAtPath(_ obj: Any, _ path: String) -> Any? {
        var current: Any = obj
        for key in path.split(separator: ".") {
            guard let dict = current as? [String: Any], let next = dict[String(key)] else { return nil }
            current = next
        }
        return current
    }
    private static func urlEncoded(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
