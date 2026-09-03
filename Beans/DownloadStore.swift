import Foundation

/// 已下载的歌曲记录
struct DownloadedSong: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let songID: Int
    let name: String
    let artist: String
    let album: String
    let coverURL: String
    let quality: String
    let fileName: String
    let folderID: UUID
    let fileSize: Int64
    let duration: TimeInterval
    let source: String
    let downloadedAt: Date
    var fileURL: URL? {
        guard let folder = DownloadStore.shared.folders.first(where: { $0.id == folderID }) else { return nil }
        return folder.directoryURL.appendingPathComponent(fileName)
    }
}

/// 用户创建的下载文件夹
struct DownloadFolder: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date
    var directoryName: String
    var directoryURL: URL {
        DownloadStore.shared.downloadsRoot.appendingPathComponent(directoryName, isDirectory: true)
    }
    var songCount: Int {
        DownloadStore.shared.songs.filter { $0.folderID == id }.count
    }
    var totalSize: Int64 {
        DownloadStore.shared.songs.filter { $0.folderID == id }.reduce(0) { $0 + $1.fileSize }
    }
}

/// 下载文件夹与已下载歌曲管理
final class DownloadStore: ObservableObject {
    static let shared = DownloadStore()
    @Published private(set) var folders: [DownloadFolder] = []
    @Published private(set) var songs: [DownloadedSong] = []
    @Published var currentFolderID: UUID?
    private let defaults = UserDefaults.standard
    private let foldersKey = "music.download.folders.v1"
    private let songsKey = "music.download.songs.v1"
    private let currentKey = "music.download.currentFolder.v1"

    var downloadsRoot: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = docs.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private init() {
        load()
        if folders.isEmpty {
            let defaultFolder = DownloadFolder(name: "全部音乐", createdAt: Date(), directoryName: "default")
            folders = [defaultFolder]
            currentFolderID = defaultFolder.id
            save()
        }
        if currentFolderID == nil { currentFolderID = folders.first?.id }
    }

    private func load() {
        if let data = defaults.data(forKey: foldersKey),
           let saved = try? JSONDecoder().decode([DownloadFolder].self, from: data) {
            folders = saved
        }
        if let data = defaults.data(forKey: songsKey),
           let saved = try? JSONDecoder().decode([DownloadedSong].self, from: data) {
            songs = saved
        }
        currentFolderID = (defaults.string(forKey: currentKey)).flatMap { UUID(uuidString: $0) } ?? folders.first?.id
    }

    private func save() {
        if let data = try? JSONEncoder().encode(folders) { defaults.set(data, forKey: foldersKey) }
        if let data = try? JSONEncoder().encode(songs) { defaults.set(data, forKey: songsKey) }
        if let id = currentFolderID { defaults.set(id.uuidString, forKey: currentKey) }
    }

    @discardableResult
    func createFolder(named name: String) -> DownloadFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let dirName = "folder_\(UUID().uuidString.prefix(8))"
        let folder = DownloadFolder(name: trimmed.isEmpty ? "新建文件夹" : trimmed, createdAt: Date(), directoryName: dirName)
        try? FileManager.default.createDirectory(at: folder.directoryURL, withIntermediateDirectories: true)
        folders.insert(folder, at: 0)
        currentFolderID = folder.id
        save()
        return folder
    }

    func renameFolder(_ id: UUID, to newName: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func deleteFolder(_ id: UUID) {
        guard let folder = folders.first(where: { $0.id == id }) else { return }
        songs.filter { $0.folderID == id }.forEach { song in
            if let url = song.fileURL { try? FileManager.default.removeItem(at: url) }
        }
        songs.removeAll { $0.folderID == id }
        try? FileManager.default.removeItem(at: folder.directoryURL)
        folders.removeAll { $0.id == id }
        if currentFolderID == id { currentFolderID = folders.first?.id }
        save()
    }

    func setCurrentFolder(_ id: UUID) {
        currentFolderID = id
        save()
    }

    @discardableResult
    func addDownloadedSong(song: Song, quality: String, from tempURL: URL, folderID: UUID? = nil) -> DownloadedSong? {
        let targetFolderID = folderID ?? currentFolderID ?? folders.first?.id ?? createFolder(named: "全部音乐").id
        guard let folder = folders.first(where: { $0.id == targetFolderID }) else { return nil }
        let safeName = "\(song.name) - \(song.artists).mp3".replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        let destURL = folder.directoryURL.appendingPathComponent(safeName)
        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.moveItem(at: tempURL, to: destURL)
        } catch {
            do { try FileManager.default.copyItem(at: tempURL, to: destURL) } catch { return nil }
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: destURL.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        let recorded = DownloadedSong(
            songID: song.id, name: song.name, artist: song.artists, album: song.album,
            coverURL: song.coverURL?.absoluteString ?? "", quality: quality,
            fileName: safeName, folderID: targetFolderID, fileSize: size,
            duration: song.duration, source: song.source == .netease ? "网易云" : (song.source == .qq ? "QQ音乐" : "酷狗"), downloadedAt: Date()
        )
        songs.insert(recorded, at: 0)
        save()
        return recorded
    }

    func deleteDownloadedSong(_ id: UUID) {
        guard let song = songs.first(where: { $0.id == id }) else { return }
        if let url = song.fileURL { try? FileManager.default.removeItem(at: url) }
        songs.removeAll { $0.id == id }
        save()
    }

    func songs(in folderID: UUID) -> [DownloadedSong] {
        songs.filter { $0.folderID == folderID }
    }

    func isDownloaded(songID: Int) -> Bool {
        songs.contains { $0.songID == songID }
    }

    static func formatSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / 1024 / 1024) }
        return String(format: "%.2f GB", Double(bytes) / 1024 / 1024 / 1024)
    }
}
