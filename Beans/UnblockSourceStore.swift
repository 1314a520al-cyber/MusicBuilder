import Foundation
/// 音乐源（原“第三方解锁源”）。
/// kind：paid-lx、paid-cr、paid-qt 为内置插件运行时格式；custom 为用户自行添加的音源。
/// template：请求 URL 模板，支持 {id}、{source}、{quality}、{name}、{keyword}、{artist}、{key} 占位符。
/// urlPath：响应 JSON 中播放地址所在的点分路径，支持 `|` 分隔多个候选路径。
/// requiresKey / cardKey：该音源是否需要卡密；需要时播放与请求会自动携带 {key} / 请求头。
struct ThirdPartySource: Identifiable, Codable, Hashable, Sendable {
    var id = UUID().uuidString
    var name: String
    var kind: String = "custom"
    var template: String
    var urlPath: String = "url"
    var headers: [String: String] = [:]
    var enabled: Bool = true
    var isPreset: Bool = false
    /// 是否需要卡密（需要卡密的音源，未填写卡密时不会参与播放解析）
    var requiresKey: Bool = false
    /// 用户填写的卡密
    var cardKey: String = ""
    /// 购买后“同步歌单”的请求地址模板（为空表示该音源不支持同步歌单），支持 {key}
    var playlistTemplate: String = ""
    /// 返回 JSON 中歌曲数组所在的点分路径，支持 | 多候选
    var playlistPath: String = "data|list|songs|tracks"
    /// 每首歌曲字典里直链播放地址的字段名，支持 | 多候选
    var songURLField: String = "url|playUrl|audioUrl|src"
    enum CodingKeys: String, CodingKey {
        case id, name, kind, template, urlPath, headers, enabled, isPreset
        case requiresKey, cardKey, playlistTemplate, playlistPath, songURLField
    }
    init(
        id: String = UUID().uuidString,
        name: String,
        kind: String = "custom",
        template: String,
        urlPath: String = "url",
        headers: [String: String] = [:],
        enabled: Bool = true,
        isPreset: Bool = false,
        requiresKey: Bool = false,
        cardKey: String = "",
        playlistTemplate: String = "",
        playlistPath: String = "data|list|songs|tracks",
        songURLField: String = "url|playUrl|audioUrl|src"
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.template = template
        self.urlPath = urlPath
        self.headers = headers
        self.enabled = enabled
        self.isPreset = isPreset
        self.requiresKey = requiresKey
        self.cardKey = cardKey
        self.playlistTemplate = playlistTemplate
        self.playlistPath = playlistPath
        self.songURLField = songURLField
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "未命名音源"
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "custom"
        template = try container.decodeIfPresent(String.self, forKey: .template) ?? ""
        urlPath = try container.decodeIfPresent(String.self, forKey: .urlPath) ?? "url"
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        isPreset = try container.decodeIfPresent(Bool.self, forKey: .isPreset) ?? false
        requiresKey = try container.decodeIfPresent(Bool.self, forKey: .requiresKey) ?? false
        cardKey = try container.decodeIfPresent(String.self, forKey: .cardKey) ?? ""
        playlistTemplate = try container.decodeIfPresent(String.self, forKey: .playlistTemplate) ?? ""
        playlistPath = try container.decodeIfPresent(String.self, forKey: .playlistPath) ?? "data|list|songs|tracks"
        songURLField = try container.decodeIfPresent(String.self, forKey: .songURLField) ?? "url|playUrl|audioUrl|src"
    }
    /// 是否缺少播放所必需的卡密
    var missingKey: Bool { requiresKey && cardKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// 是否支持“同步歌单”（配置了同步地址且需要的卡密已填）
    var canSyncPlaylist: Bool {
        !playlistTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !missingKey
    }
}
/// 音乐源管理：内置预设 + 用户自定义音源，统一持久化，播放时由 UnblockService 自动并发识别。
final class UnblockSourceStore: ObservableObject {
    static let shared = UnblockSourceStore()
    private static let paidAPIURL = "https://source.shiqianjiang.cn/api/music"
    private static let paidURLTemplate = "\(paidAPIURL)/url?source={source}&songId={id}&quality={quality}&key={key}"
    /// 内置预设音源（LX / CR / QT，最终调用同一接口，播放时按请求指纹去重）。
    /// 内置音源同样需要卡密：用户填写卡密后，播放请求自动携带 {key} / X-API-Key / Authorization。
    static let paidPresetSources: [ThirdPartySource] = [
        ThirdPartySource(
            id: "beans.preset.shiqianjiang.lx.v7",
            name: "聆澜音源 · LX",
            kind: "paid-lx",
            template: paidURLTemplate,
            headers: ["quality": "320k"],
            isPreset: true,
            requiresKey: true,
            cardKey: ""
        ),
        ThirdPartySource(
            id: "beans.preset.shiqianjiang.cr.v7",
            name: "聆澜音源 · CR",
            kind: "paid-cr",
            template: paidURLTemplate,
            headers: ["quality": "320k"],
            isPreset: true,
            requiresKey: true,
            cardKey: ""
        ),
        ThirdPartySource(
            id: "beans.preset.shiqianjiang.qt.v7",
            name: "聆澜音源 · QT",
            kind: "paid-qt",
            template: paidURLTemplate,
            headers: ["quality": "320k"],
            isPreset: true,
            requiresKey: true,
            cardKey: ""
        ),
        // 免费音源：pyncmd（来自 Kumone，按网易云歌曲 ID 解析，无需卡密）
        ThirdPartySource(
            id: "music.preset.pyncmd.v1",
            name: "Pyncmd 音源",
            kind: "custom",
            template: "https://music-api.gdstudio.xyz/api.php?types=url&source=netease&id={id}&br=320",
            urlPath: "url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：网易云镜像（Meting API 格式）
        ThirdPartySource(
            id: "music.preset.meting.v1",
            name: "Meting 音源",
            kind: "custom",
            template: "https://api.i-meto.com/meting/api?server=netease&type=url&id={id}",
            urlPath: "url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：酷狗解析（按 hash）
        ThirdPartySource(
            id: "music.preset.kugoufree.v1",
            name: "酷狗免费解析",
            kind: "custom",
            template: "https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash={id}&mid=1",
            urlPath: "data.play_url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：QQ 音乐解析
        ThirdPartySource(
            id: "music.preset.qqfree.v1",
            name: "QQ 免费解析",
            kind: "custom",
            template: "https://api.qq.jsososo.com/song/url?id={id}",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：酷我解析
        ThirdPartySource(
            id: "music.preset.kuwo.v1",
            name: "酷我音源",
            kind: "custom",
            template: "https://www.kuwo.cn/api/v1/www/music/playUrl?mid={id}&type=music&httpsStatus=1",
            urlPath: "data.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：咪咕解析
        ThirdPartySource(
            id: "music.preset.migu.v1",
            name: "咪咕音源",
            kind: "custom",
            template: "https://api.migu.jsososo.com/song/url?id={id}",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：网易云镜像2
        ThirdPartySource(
            id: "music.preset.netease2.v1",
            name: "网易云镜像",
            kind: "custom",
            template: "https://netease-cloud-music-api-ebon-seven.vercel.app/song/url/v1?id={id}&level=exhigh",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：QQ音乐镜像
        ThirdPartySource(
            id: "music.preset.qq2.v1",
            name: "QQ镜像音源",
            kind: "custom",
            template: "https://api.qq.jsososo.com/song/url?id={id}&type=320",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：全民K歌解析
        ThirdPartySource(
            id: "music.preset.kgfree.v1",
            name: "酷狗高品解析",
            kind: "custom",
            template: "https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash={id}&mid=1&platid=4",
            urlPath: "data.play_url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：网易云无损
        ThirdPartySource(
            id: "music.preset.netease_hires.v1",
            name: "网易云无损",
            kind: "custom",
            template: "https://netease-cloud-music-api-ebon-seven.vercel.app/song/url/v1?id={id}&level=lossless",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：QQ高品解析
        ThirdPartySource(
            id: "music.preset.qq_hires.v1",
            name: "QQ高品解析",
            kind: "custom",
            template: "https://api.qq.jsososo.com/song/url?id={id}&type=flac",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：咪咕高品
        ThirdPartySource(
            id: "music.preset.migu_hires.v1",
            name: "咪咕高品",
            kind: "custom",
            template: "https://api.migu.jsososo.com/song/url?id={id}&quality=flac",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：酷我无损
        ThirdPartySource(
            id: "music.preset.kuwo_hires.v1",
            name: "酷我无损",
            kind: "custom",
            template: "https://www.kuwo.cn/api/v1/www/music/playUrl?mid={id}&type=flac&httpsStatus=1",
            urlPath: "data.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：全民解析
        ThirdPartySource(
            id: "music.preset.universal.v1",
            name: "全民解析",
            kind: "custom",
            template: "https://api.injahow.cn/meting/?type=url&server={source}&id={id}",
            urlPath: "url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：网易云320K
        ThirdPartySource(
            id: "music.preset.netease_320.v1",
            name: "网易云320K",
            kind: "custom",
            template: "https://music-api.gdstudio.xyz/api.php?types=url&source=netease&id={id}&br=320",
            urlPath: "url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：QQ无损解析
        ThirdPartySource(
            id: "music.preset.qq_lossless.v1",
            name: "QQ无损解析",
            kind: "custom",
            template: "https://api.qq.jsososo.com/song/url?id={id}&type=ape",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：酷狗无损
        ThirdPartySource(
            id: "music.preset.kugou_lossless.v1",
            name: "酷狗无损",
            kind: "custom",
            template: "https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash={id}&mid=1&platid=4&album_id=0",
            urlPath: "data.play_url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：咪咕无损
        ThirdPartySource(
            id: "music.preset.migu_lossless.v1",
            name: "咪咕无损",
            kind: "custom",
            template: "https://api.migu.jsososo.com/song/url?id={id}&quality=ape",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：网易云高品
        ThirdPartySource(
            id: "music.preset.netease_exhigh.v1",
            name: "网易云高品",
            kind: "custom",
            template: "https://netease-cloud-music-api-ebon-seven.vercel.app/song/url/v1?id={id}&level=exhigh",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：QQ320K
        ThirdPartySource(
            id: "music.preset.qq_320.v1",
            name: "QQ320K",
            kind: "custom",
            template: "https://api.qq.jsososo.com/song/url?id={id}&type=320",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：酷狗高品
        ThirdPartySource(
            id: "music.preset.kugou_320.v1",
            name: "酷狗320K",
            kind: "custom",
            template: "https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash={id}&mid=1&platid=4&album_id=0",
            urlPath: "data.play_url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：酷我320K
        ThirdPartySource(
            id: "music.preset.kuwo_320.v1",
            name: "酷我320K",
            kind: "custom",
            template: "https://www.kuwo.cn/api/v1/www/music/playUrl?mid={id}&type=music&httpsStatus=1&br=320kmp3",
            urlPath: "data.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：网易云镜像2
        ThirdPartySource(
            id: "music.preset.netease_mirror2.v1",
            name: "网易云镜像2",
            kind: "custom",
            template: "https://netease-cloud-music-api-tan-omega.vercel.app/song/url/v1?id={id}&level=exhigh",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：QQ镜像2
        ThirdPartySource(
            id: "music.preset.qq_mirror2.v1",
            name: "QQ镜像2",
            kind: "custom",
            template: "https://api.qq.jsososo.com/song/url?id={id}&type=flac",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：咪咕镜像
        ThirdPartySource(
            id: "music.preset.migu_mirror.v1",
            name: "咪咕镜像",
            kind: "custom",
            template: "https://api.migu.jsososo.com/song/url?id={id}&quality=flac",
            urlPath: "data.0.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：全民解析2
        ThirdPartySource(
            id: "music.preset.universal2.v1",
            name: "全民解析2",
            kind: "custom",
            template: "https://api.injahow.cn/meting/?type=url&server={source}&id={id}",
            urlPath: "url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：酷狗镜像
        ThirdPartySource(
            id: "music.preset.kugou_mirror.v1",
            name: "酷狗镜像",
            kind: "custom",
            template: "https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash={id}&mid=1&platid=4&album_id=0",
            urlPath: "data.play_url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：咪咕高清2
        ThirdPartySource(
            id: "music.preset.migu_hd2.v1",
            name: "咪咕高清2",
            kind: "custom",
            template: "https://c.musicapp.migu.cn/MIGUM2.0/v1.0/content/listen-url?contentId={id}&netType=01&resourceType=E",
            urlPath: "data.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：千千音乐
        ThirdPartySource(
            id: "music.preset.qianqian.v1",
            name: "千千音乐",
            kind: "custom",
            template: "https://musicapi.taihe.com/v1/restserver/ting?method=baidu.ting.song.play&songid={id}",
            urlPath: "bitrate.file_link",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：酷我无损2
        ThirdPartySource(
            id: "music.preset.kuwo_flac2.v1",
            name: "酷我无损2",
            kind: "custom",
            template: "https://www.kuwo.cn/api/v1/www/music/playUrl?mid={id}&type=flac&httpsStatus=1",
            urlPath: "data.url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：JOOX镜像
        ThirdPartySource(
            id: "music.preset.joox.v1",
            name: "JOOX镜像",
            kind: "custom",
            template: "https://api.joox.com/web-fcgi-bin/web_get_songinfo?songid={id}&lang=zh",
            urlPath: "r320Url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：5sing原创
        ThirdPartySource(
            id: "music.preset.five_sing.v1",
            name: "5sing原创",
            kind: "custom",
            template: "https://5sing.kugou.com/app/song/info?songid={id}",
            urlPath: "data.squrl",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：CeruMusic（聚合解析，支持多平台）
        ThirdPartySource(
            id: "music.preset.cerumusic.v1",
            name: "CeruMusic",
            kind: "custom",
            template: "https://api.ceru.cn/music/url?source={source}&id={id}&quality=320",
            urlPath: "data.url|url|data.play_url",
            headers: [:],
            isPreset: true
        ),
        // 免费音源：全豆要聚合（多平台聚合解析）
        ThirdPartySource(
            id: "music.preset.quandou.v1",
            name: "全豆要聚合",
            kind: "custom",
            template: "https://api.quandou.com/music?source={source}&id={id}&br=320",
            urlPath: "data.url|url|result.url",
            headers: [:],
            isPreset: true
        ),
    ]
    @Published var presetSources: [ThirdPartySource] {
        didSet { save() }
    }
    /// 已启用且配置完整（卡密已填）的可用音源
    var availableSources: [ThirdPartySource] {
        presetSources.filter { $0.enabled && !$0.missingKey && !$0.template.isEmpty }
    }
    private let defaults = UserDefaults.standard
    private let presetsKey = "beans.unblock.presets"
    private let legacyCustomKey = "beans.unblock.custom"
    private let legacyLXKey = "beans.unblock.lxScripts"
    private init() {
        let savedSources: [ThirdPartySource]
        if let data = defaults.data(forKey: presetsKey),
           let list = try? JSONDecoder().decode([ThirdPartySource].self, from: data) {
            savedSources = list
        } else if let data = defaults.data(forKey: legacyCustomKey),
                  let list = try? JSONDecoder().decode([ThirdPartySource].self, from: data) {
            savedSources = list
        } else {
            savedSources = []
        }
        // 旧版本的导入源和旧版预设不再参与播放，避免导入脚本继续触发网络请求。
        let existingPresets = savedSources.filter { $0.isPreset }
        presetSources = Self.seedPaidPresets(into: existingPresets)
        // 保留用户自定义音源（非预设），追加在内置预设之后
        let custom = savedSources.filter { !$0.isPreset }
        if !custom.isEmpty { presetSources.append(contentsOf: custom) }
        defaults.removeObject(forKey: legacyCustomKey)
        defaults.removeObject(forKey: legacyLXKey)
        save()
    }
    private func save() {
        if let data = try? JSONEncoder().encode(presetSources) {
            defaults.set(data, forKey: presetsKey)
        }
    }
    private static func seedPaidPresets(into savedSources: [ThirdPartySource]) -> [ThirdPartySource] {
        var seeded = savedSources
        for preset in paidPresetSources {
            if let index = seeded.firstIndex(where: { $0.id == preset.id }) {
                var updated = preset
                updated.enabled = seeded[index].enabled
                // 保留用户已填写的卡密，避免升级后丢失
                if !seeded[index].cardKey.isEmpty {
                    updated.cardKey = seeded[index].cardKey
                }
                seeded[index] = updated
            } else {
                seeded.append(preset)
            }
        }
        return seeded
    }
    // MARK: - 增 / 改 / 删
    /// 新增一个用户自定义音乐源
    func addSource(
        name: String,
        template: String,
        urlPath: String,
        requiresKey: Bool,
        cardKey: String,
        quality: String,
        playlistTemplate: String = "",
        playlistPath: String = "data|list|songs|tracks",
        songURLField: String = "url|playUrl|audioUrl|src",
        enabled: Bool = true
    ) {
        var headers: [String: String] = [:]
        let q = quality.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { headers["quality"] = q }
        let source = ThirdPartySource(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自定义音源" : name,
            kind: "custom",
            template: template.trimmingCharacters(in: .whitespacesAndNewlines),
            urlPath: urlPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "url" : urlPath,
            headers: headers,
            enabled: enabled,
            isPreset: false,
            requiresKey: requiresKey,
            cardKey: cardKey.trimmingCharacters(in: .whitespacesAndNewlines),
            playlistTemplate: playlistTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
            playlistPath: playlistPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "data|list|songs|tracks" : playlistPath,
            songURLField: songURLField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "url|playUrl|audioUrl|src" : songURLField
        )
        presetSources.append(source)
    }
    /// 更新指定音源（主要用于编辑卡密 / 开关 / 模板）
    func updateSource(_ source: ThirdPartySource) {
        guard let index = presetSources.firstIndex(where: { $0.id == source.id }) else { return }
        presetSources[index] = source
    }
    func setEnabled(_ id: String, _ enabled: Bool) {
        guard let index = presetSources.firstIndex(where: { $0.id == id }) else { return }
        presetSources[index].enabled = enabled
    }
    func setCardKey(_ id: String, key: String) {
        guard let index = presetSources.firstIndex(where: { $0.id == id }) else { return }
        presetSources[index].cardKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// 统一卡密：把同一份卡密同步到所有需要卡密的内置音源（LX / CR / QT 共用）。
    /// 返回受影响的内置音源数量，便于 UI 提示。
    @discardableResult
    func applyCardKeyToPresets(_ key: String) -> Int {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        var count = 0
        for index in presetSources.indices where presetSources[index].isPreset && presetSources[index].requiresKey {
            presetSources[index].cardKey = trimmed
            count += 1
        }
        return count
    }
    /// 内置需要卡密的音源当前是否已全部填好卡密
    var presetsKeyConfigured: Bool {
        let needed = presetSources.filter { $0.isPreset && $0.requiresKey }
        return !needed.isEmpty && needed.allSatisfy { !$0.missingKey }
    }
    /// 获取内置音源共用的卡密（未填时返回空串）
    var sharedPresetKey: String {
        presetSources.first { $0.isPreset && $0.requiresKey && !$0.missingKey }?.cardKey ?? ""
    }
    /// 仅允许删除用户自定义音源，内置预设不可删除
    /// 直接添加一个 ThirdPartySource（用于导入功能）
    func addCustomSource(_ source: ThirdPartySource) {
        var newSource = source
        newSource.isPreset = false
        newSource.kind = "custom"
        presetSources.append(newSource)
    }
    
    func removeSource(_ id: String) {
        guard let index = presetSources.firstIndex(where: { $0.id == id }),
              !presetSources[index].isPreset else { return }
        presetSources.remove(at: index)
    }
}
