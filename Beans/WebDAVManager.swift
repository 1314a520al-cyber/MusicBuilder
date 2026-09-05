import Foundation
import UIKit

// MARK: - WebDAV 远程备份管理器

@MainActor
final class WebDAVManager: ObservableObject {
    static let shared = WebDAVManager()
    
    private let defaults = UserDefaults.standard
    private let serverKey = "webdav.server"
    private let accountKey = "webdav.account"
    private let passwordKey = "webdav.password"
    private let enabledKey = "webdav.enabled"
    private let lastBackupKey = "webdav.lastBackup"
    
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var lastError: String?
    @Published var backupFiles: [WebDAVFile] = []
    
    var server: String {
        get { defaults.string(forKey: serverKey) ?? "" }
        set { defaults.set(newValue, forKey: serverKey) }
    }
    var account: String {
        get { defaults.string(forKey: accountKey) ?? "" }
        set { defaults.set(newValue, forKey: accountKey) }
    }
    var password: String {
        get { defaults.string(forKey: passwordKey) ?? "" }
        set { defaults.set(newValue, forKey: passwordKey) }
    }
    var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }
    var lastBackup: Date {
        get { Date(timeIntervalSince1970: defaults.double(forKey: lastBackupKey)) }
        set { defaults.set(newValue.timeIntervalSince1970, forKey: lastBackupKey) }
    }
    var hasBackup: Bool { defaults.double(forKey: lastBackupKey) > 0 }
    
    var isConfigured: Bool {
        !server.isEmpty && !account.isEmpty
    }
    
    private init() {}
    
    struct WebDAVFile: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
        let size: Int64
        let modified: Date?
    }
    
    struct BackupData: Codable {
        let version: String
        let timestamp: Double
        let deviceName: String
        let playlists: [UserPlaylist]
        let favorites: [Song]
        let settings: [String: String]
    }
    
    // MARK: - 测试连接
    
    func testConnection() async -> Bool {
        guard let url = URL(string: server) else {
            lastError = "服务器地址无效"
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        addAuth(to: &request)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                lastError = nil
                return true
            }
            lastError = "连接失败（HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)）"
            return false
        } catch {
            lastError = "连接失败：\(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - 上传备份
    
    func backup() async -> Bool {
        guard isConfigured else {
            lastError = "请先配置WebDAV"
            return false
        }
        
        isBackingUp = true
        lastError = nil
        
        do {
            let data = try await buildBackupData()
            let jsonData = try JSONEncoder().encode(data)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let filename = "music_backup_\(dateFormatter.string(from: Date())).json"
            
            guard let baseURL = URL(string: server) else {
                lastError = "服务器地址无效"
                isBackingUp = false
                return false
            }
            
            let fileURL = baseURL.appendingPathComponent(filename)
            var request = URLRequest(url: fileURL)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            addAuth(to: &request)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                lastBackup = Date()
                isBackingUp = false
                return true
            }
            lastError = "上传失败（HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)）"
        } catch {
            lastError = "备份失败：\(error.localizedDescription)"
        }
        
        isBackingUp = false
        return false
    }
    
    // MARK: - 列出备份文件
    
    func listBackups() async {
        guard isConfigured, let url = URL(string: server) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        addAuth(to: &request)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            backupFiles = parsePROPFIND(data: data, baseURL: url)
        } catch {
            lastError = "获取列表失败：\(error.localizedDescription)"
        }
    }
    
    // MARK: - 下载恢复
    
    func restore(from file: WebDAVFile) async -> Bool {
        isRestoring = true
        lastError = nil
        
        do {
            var request = URLRequest(url: file.url)
            request.httpMethod = "GET"
            addAuth(to: &request)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let backup = try JSONDecoder().decode(BackupData.self, from: data)
            
            for playlist in backup.playlists {
                if !UserPlaylistStore.shared.playlists.contains(where: { $0.name == playlist.name }) {
                    let newPL = UserPlaylistStore.shared.create(named: playlist.name)
                    for song in playlist.songs {
                        _ = UserPlaylistStore.shared.add(song: song, to: newPL.id)
                    }
                }
            }
            
            for song in backup.favorites {
                if !FavoritesStore.shared.isLiked(song) {
                    _ = await FavoritesStore.shared.toggle(song)
                }
            }
            
            isRestoring = false
            return true
        } catch {
            lastError = "恢复失败：\(error.localizedDescription)"
        }
        
        isRestoring = false
        return false
    }
    
    // MARK: - Private
    
    private func buildBackupData() async throws -> BackupData {
        BackupData(
            version: "1.0",
            timestamp: Date().timeIntervalSince1970,
            deviceName: UIDevice.current.name,
            playlists: UserPlaylistStore.shared.playlists,
            favorites: FavoritesStore.shared.localSongs,
            settings: [:]
        )
    }
    
    private func addAuth(to request: inout URLRequest) {
        let authString = "\(account):\(password)"
        if let authData = authString.data(using: .utf8) {
            request.setValue("Basic \(authData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func parsePROPFIND(data: Data, baseURL: URL) -> [WebDAVFile] {
        var files: [WebDAVFile] = []
        let xml = String(data: data, encoding: .utf8) ?? ""
        
        let responses = xml.components(separatedBy: "<D:response>")
        for response in responses.dropFirst() {
            guard let hrefRange = response.range(of: "<D:href>")?.upperBound,
                  let hrefEnd = response[hrefRange...].range(of: "</D:href>")?.lowerBound,
                  let nameRange = response.range(of: "<D:displayname>")?.upperBound,
                  let nameEnd = response[nameRange...].range(of: "</D:displayname>")?.lowerBound else {
                continue
            }
            
            let href = String(response[hrefRange..<hrefEnd])
            let name = String(response[nameRange..<nameEnd])
            
            if name.hasSuffix(".json") || name.contains("backup") {
                if let decodedHref = href.removingPercentEncoding,
                   let fileURL = URL(string: decodedHref, relativeTo: baseURL) ?? URL(string: decodedHref) {
                    files.append(WebDAVFile(name: name, url: fileURL, size: 0, modified: nil))
                }
            }
        }
        return files
    }
}
