import SwiftUI

/// 添加 / 编辑音乐源。
/// 传入 `editing` 为编辑模式，否则为新增模式。
/// 只有打开“需要卡密”时才出现卡密输入框；不需要卡密的音源无需填写。
import UniformTypeIdentifiers

struct MusicSourceSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var showFileImporter = false
    @ObservedObject private var store = UnblockSourceStore.shared

    /// 编辑中的已有音源（nil 表示新增）
    var editing: ThirdPartySource?

    @State private var name: String = ""
    @State private var template: String = ""
    @State private var urlPath: String = "url"
    @State private var quality: String = "320k"
    @State private var requiresKey: Bool = false
    @State private var cardKey: String = ""
    @State private var showKey: Bool = false
    /// 同步歌单（购买后）
    @State private var supportsSync: Bool = false
    @State private var playlistTemplate: String = ""
    @State private var playlistPath: String = "data|list|songs|tracks"
    @State private var songURLField: String = "url|playUrl|audioUrl|src"
    @State private var errorText: String?

    private var isEdit: Bool { editing != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedTemplate: String { template.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        guard !trimmedName.isEmpty, !trimmedTemplate.isEmpty, trimmedTemplate.hasPrefix("http") else { return false }
        if requiresKey, cardKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        fieldCard {
                            fieldLabel("音源名称", systemName: "music.note")
                            TextField("例如：我的音源", text: $name)
                                .font(BeansFont.appFont(14))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        fieldCard {
                            fieldLabel("请求地址模板", systemName: "link")
                            TextField("https://example.com/api?name={keyword}&key={key}", text: $template)
                                .font(BeansFont.appFont(13, .regular, .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                            Text("可用占位符：{keyword} 歌名+歌手、{name} 歌名、{artist} 歌手、{id} 平台歌曲ID、{source} 平台、{quality} 音质、{key} 卡密")
                                .font(BeansFont.appFont(10))
                                .foregroundStyle(Color.beansComment)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        fieldCard {
                            fieldLabel("播放地址字段路径", systemName: "arrow.triangle.branch")
                            TextField("url", text: $urlPath)
                                .font(BeansFont.appFont(13, .regular, .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Text("接口返回 JSON 中真实播放地址所在字段，支持点分路径与 | 多候选，例如 data.url|url")
                                .font(BeansFont.appFont(10))
                                .foregroundStyle(Color.beansComment)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        fieldCard {
                            fieldLabel("音质（可留空）", systemName: "waveform")
                            TextField("320k", text: $quality)
                                .font(BeansFont.appFont(13, .regular, .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        // 是否需要卡密
                        fieldCard {
                            Toggle(isOn: $requiresKey) {
                                HStack(spacing: 12) {
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.beansAmber)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("该音源需要卡密")
                                            .font(BeansFont.appFont(15))
                                            .foregroundStyle(Color.beansLabel)
                                        Text("开启后需填写卡密才能播放；不需要卡密的音源请关闭")
                                            .font(BeansFont.appFont(11))
                                            .foregroundStyle(Color.beansComment)
                                    }
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(Color.beansAmber)
                            if requiresKey {
                                Divider().overlay(Color.beansComment.opacity(0.15))
                                fieldLabel("卡密", systemName: "textformat.123")
                                HStack(spacing: 8) {
                                    Group {
                                        if showKey {
                                            TextField("请输入卡密", text: $cardKey)
                                        } else {
                                            SecureField("请输入卡密", text: $cardKey)
                                        }
                                    }
                                    .font(BeansFont.appFont(13, .regular, .monospaced))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    Button {
                                        showKey.toggle()
                                    } label: {
                                        Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.beansComment)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        // 同步歌单（购买后可用）
                        fieldCard {
                            Toggle(isOn: $supportsSync) {
                                HStack(spacing: 12) {
                                    Image(systemName: "tray.and.arrow.down.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.beansAmber)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("购买后支持同步歌单")
                                            .font(BeansFont.appFont(15))
                                            .foregroundStyle(Color.beansLabel)
                                        Text("开启后可在设置里一键把该音源的歌单同步到音乐库")
                                            .font(BeansFont.appFont(11))
                                            .foregroundStyle(Color.beansComment)
                                    }
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(Color.beansAmber)
                            if supportsSync {
                                Divider().overlay(Color.beansComment.opacity(0.15))
                                fieldLabel("歌单同步地址", systemName: "square.stack.3d.up.fill")
                                TextField("https://example.com/playlist?key={key}", text: $playlistTemplate)
                                    .font(BeansFont.appFont(13, .regular, .monospaced))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                                Text("可用 {key} 自动带入卡密；返回 JSON 中需包含歌曲列表")
                                    .font(BeansFont.appFont(10))
                                    .foregroundStyle(Color.beansComment)
                                fieldLabel("歌曲列表字段路径", systemName: "arrow.triangle.branch")
                                TextField("data|list|songs|tracks", text: $playlistPath)
                                    .font(BeansFont.appFont(12, .regular, .monospaced))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                fieldLabel("歌曲直链字段名", systemName: "link.badge.plus")
                                TextField("url|playUrl|audioUrl|src", text: $songURLField)
                                    .font(BeansFont.appFont(12, .regular, .monospaced))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                        }
                        if let errorText {
                            Text(errorText)
                                .font(BeansFont.appFont(12))
                                .foregroundStyle(.red)
                        }
                        Button {
                            save()
                        } label: {
                            Text(isEdit ? "保存修改" : "添加音乐源")
                                .font(BeansFont.appFont(15, .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(canSave ? Color.beansAmber : Color.beansComment.opacity(0.4)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                        Text("添加后会在播放时自动参与识别：官方地址不可用时，并发请求所有已启用音源，最快可用者播放。")
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle(isEdit ? "编辑音乐源" : "添加音乐源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("从文件导入", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: [.json, .plainText, .data, .item],
                          allowsMultipleSelection: false) { result in
                guard let url = try? result.get().first else { return }
                importFromFile(url)
            }
            .onAppear(perform: setup)
        }
    }

    private func fieldLabel(_ text: String, systemName: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundStyle(Color.beansAmber)
            Text(text)
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(Color.beansSecondary)
        }
    }
    private func fieldCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .beansCardShadow(radius: 8, y: 3)
    }

    private func importFromFile(_ url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8),
              let obj = parseFirstObject(text) else {
            errorText = "未识别到音源配置"; return
        }
        func str(_ keys: [String]) -> String {
            for k in keys {
                if let v = obj[k] as? String, !v.isEmpty { return v }
            }
            return ""
        }
        let importedName = str(["name", "title", "名称", "音源名称", "备注"])
        let importedTemplate = str(["template", "url", "api", "searchUrl", "search", "地址", "接口", "请求地址", "链接"])
        guard !importedTemplate.isEmpty else { errorText = "文件中缺少请求地址"; return }
        name = importedName.isEmpty ? "导入的音源" : importedName
        template = importedTemplate
        let up = str(["urlPath", "songURLField", "urlField", "playUrl", "直链字段", "地址字段"])
        if !up.isEmpty { urlPath = up; songURLField = up }
        let lp = str(["listPath", "list", "搜索列表字段", "列表字段"])
        let pl = str(["playlistTemplate", "playlist", "playlistUrl", "歌单地址", "同步地址"])
        if !pl.isEmpty {
            supportsSync = true
            playlistTemplate = pl
            let pp = str(["playlistPath", "歌单列表字段"]); if !pp.isEmpty { playlistPath = pp }
        }
        let q = str(["quality", "音质", "码率"]); if !q.isEmpty { quality = q }
        let key = str(["cardKey", "key", "token", "卡密", "密钥", "apikey", "apiKey"])
        cardKey = key
        var req = false
        if let b = obj["requiresKey"] as? Bool { req = b }
        else if let s = obj["requiresKey"] as? String { req = s == "1" || s.lowercased() == "true" }
        else if let n = obj["requiresKey"] as? NSNumber { req = n.boolValue }
        else { req = !key.isEmpty }
        requiresKey = req
        errorText = req && key.isEmpty ? "已识别音源，请填写卡密后保存" : nil
        BeansHaptics.success()
    }
    private func parseFirstObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let dict = json as? [String: Any] { return dict }
        if let arr = json as? [[String: Any]], let first = arr.first { return first }
        return nil
    }
    private func setup() {
        guard let editing else { return }
        name = editing.name
        template = editing.template
        urlPath = editing.urlPath
        quality = editing.headers["quality"] ?? ""
        requiresKey = editing.requiresKey
        cardKey = editing.cardKey
        supportsSync = !editing.playlistTemplate.isEmpty
        playlistTemplate = editing.playlistTemplate
        playlistPath = editing.playlistPath
        songURLField = editing.songURLField
    }

    private func save() {
        guard !trimmedName.isEmpty else { errorText = "请填写音源名称"; return }
        guard trimmedTemplate.hasPrefix("http") else { errorText = "请求地址需以 http 开头"; return }
        if requiresKey, cardKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorText = "该音源需要卡密，请填写卡密"; return
        }
        BeansHaptics.success()
        let syncURL = supportsSync ? playlistTemplate.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        if supportsSync, !syncURL.isEmpty, !syncURL.hasPrefix("http") {
            errorText = "歌单同步地址需以 http 开头"; return
        }
        let syncListPath = playlistPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "data|list|songs|tracks" : playlistPath
        let syncURLField = songURLField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "url|playUrl|audioUrl|src" : songURLField
        if let editing {
            var updated = editing
            updated.name = trimmedName
            updated.template = trimmedTemplate
            updated.urlPath = urlPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "url" : urlPath
            updated.requiresKey = requiresKey
            updated.cardKey = cardKey.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.playlistTemplate = syncURL
            updated.playlistPath = syncListPath
            updated.songURLField = syncURLField
            var headers = editing.headers
            let q = quality.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty { headers.removeValue(forKey: "quality") } else { headers["quality"] = q }
            updated.headers = headers
            store.updateSource(updated)
        } else {
            store.addSource(
                name: trimmedName,
                template: trimmedTemplate,
                urlPath: urlPath,
                requiresKey: requiresKey,
                cardKey: cardKey,
                quality: quality,
                playlistTemplate: syncURL,
                playlistPath: syncListPath,
                songURLField: syncURLField
            )
        }
        dismiss()
    }
}
