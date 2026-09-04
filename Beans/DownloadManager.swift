import Foundation
import AVFoundation
import UIKit

// MARK: - 下载音质

enum DownloadQuality: String, CaseIterable, Identifiable {
    case low
    case high
    case lossless

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: return "低质量（128kbps）"
        case .high: return "高质量（320kbps）"
        case .lossless: return "无损 FLAC（需 VIP，不可用自动降级）"
        }
    }

    var neteaseLevel: String {
        switch self {
        case .low: return "standard"
        case .high: return "exhigh"
        case .lossless: return "lossless"
        }
    }

    var qqBR: String {
        switch self {
        case .low: return "M500"
        case .high: return "M800"
        case .lossless: return "F000"
        }
    }

    var fallbackChain: [DownloadQuality] {
        switch self {
        case .lossless: return [.lossless, .high, .low]
        case .high: return [.high, .low]
        case .low: return [.low]
        }
    }
}

struct DownloadResult {
    let url: URL
    let downgraded: Bool
}

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    private init() {}
    
    @Published var downloadedSongs: [Song] = []
    @Published var activeDownloads: [String: Double] = [:]
    private let defaults = UserDefaults.standard
    private let downloadedKey = "beans.downloadedSongs"
    
    func loadDownloaded() {
        if let data = defaults.data(forKey: downloadedKey),
           let songs = try? JSONDecoder().decode([Song].self, from: data) {
            downloadedSongs = songs
        }
    }
    
    func addDownloaded(_ song: Song) {
        if !downloadedSongs.contains(where: { $0.identityKey == song.identityKey }) {
            downloadedSongs.append(song)
            saveDownloaded()
        }
    }
    
    func delete(song: Song) {
        downloadedSongs.removeAll { $0.identityKey == song.identityKey }
        saveDownloaded()
        // 删除本地文件
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docs.appendingPathComponent("downloads/\(song.identityKey).m4a")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    private func saveDownloaded() {
        if let data = try? JSONEncoder().encode(downloadedSongs) {
            defaults.set(data, forKey: downloadedKey)
        }
    }

    @discardableResult
    func download(song: Song, quality: DownloadQuality) async -> Result<DownloadResult, Error> {
        let chain = quality.fallbackChain
        var lastError: Error = NetEaseError.unknown("下载失败")

        for (index, current) in chain.enumerated() {
            guard let urlString = await resolveURL(song: song, quality: current),
                  let url = URL(string: urlString), !urlString.isEmpty else {
                lastError = NetEaseError.unknown("无法解析播放地址（可能为 VIP 歌曲）")
                continue
            }

            let tempURL: URL
            do {
                let (downloaded, response) = try await URLSession.shared.download(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    lastError = NetEaseError.unknown("下载失败（HTTP \(http.statusCode)）")
                    continue
                }
                tempURL = downloaded
            } catch {
                lastError = NetEaseError.unknown("下载失败：\(error.localizedDescription)")
                continue
            }

            // 内嵌封面+歌词+元数据，导出为单个 m4a 文件
            let finalURL = await embedMetadata(
                audioURL: tempURL,
                song: song,
                quality: current
            )

            if let finalURL = finalURL {
                return .success(DownloadResult(url: finalURL, downgraded: index > 0))
            }

            // 内嵌失败则退回原始文件
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BeansShare", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let safeName = "\(song.name) - \(song.artists)"
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let ext = current == .lossless ? "flac" : "mp3"
            let dest = dir.appendingPathComponent("\(safeName).\(ext)")
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.moveItem(at: tempURL, to: dest)
                return .success(DownloadResult(url: dest, downgraded: index > 0))
            } catch {
                lastError = error
                continue
            }
        }
        return .failure(lastError)
    }

    // MARK: - 内嵌封面+歌词+元数据为单个 m4a 文件
    private func embedMetadata(audioURL: URL, song: Song, quality: DownloadQuality) async -> URL? {
        let asset = AVURLAsset(url: audioURL)

        // 异步加载可导出性
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return nil
        }

        // 下载封面
        var artworkData: Data?
        if let coverURL = song.coverURL {
            do {
                let (data, _) = try await URLSession.shared.data(from: coverURL)
                artworkData = data
            } catch {}
        }

        // 获取歌词
        let lyrics = await fetchLyrics(song: song)

        // 构建 metadata
        var metadata: [AVMutableMetadataItem] = []

        // 标题
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = song.name as NSString
        metadata.append(titleItem)

        // 艺术家
        let artistItem = AVMutableMetadataItem()
        artistItem.identifier = .commonIdentifierArtist
        artistItem.value = song.artists as NSString
        metadata.append(artistItem)

        // 专辑
        if !song.album.isEmpty {
            let albumItem = AVMutableMetadataItem()
            albumItem.identifier = .commonIdentifierAlbumName
            albumItem.value = song.album as NSString
            metadata.append(albumItem)
        }

        // 封面
        if let artworkData = artworkData, let image = UIImage(data: artworkData) {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.identifier = .commonIdentifierArtwork
            artworkItem.value = image.pngData() as NSData?
            metadata.append(artworkItem)
        }

        // 歌词（iTunes metadata key）
        if let lyrics = lyrics, !lyrics.isEmpty {
            let lyricsItem = AVMutableMetadataItem()
            lyricsItem.key = "lyrics" as NSCopying & NSObjectProtocol
            lyricsItem.keySpace = .iTunes
            lyricsItem.value = lyrics as NSString
            metadata.append(lyricsItem)
        }

        exportSession.metadata = metadata
        exportSession.shouldOptimizeForNetworkUse = true

        // 输出路径
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BeansShare", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safeName = "\(song.name) - \(song.artists)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let outputURL = dir.appendingPathComponent("\(safeName).m4a")
        try? FileManager.default.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        }
        return nil
    }

    // MARK: - 获取歌词
    private func fetchLyrics(song: Song) async -> String? {
        do {
            if song.source == .qq, let mid = song.qqMid {
                return try await QQMusicAPI.shared.lyric(songmid: mid)
            } else if song.source == .kugou {
                return await KugouMusicAPI.shared.lyric(hash: song.kugouHash ?? "", duration: song.duration)
            } else {
                return try await NetEaseAPI.shared.lyric(id: song.id)
            }
        } catch {
            return nil
        }
    }

    private func resolveURL(song: Song, quality: DownloadQuality) async -> String? {
        if song.source == .qq, let mid = song.qqMid {
            return try? await QQMusicAPI.shared.songURL(songmid: mid, mediaMid: song.qqMediaMid, br: quality.qqBR)
        } else if song.source == .kugou {
            return try? await KugouMusicAPI.shared.songURL(song: song)
        } else {
            let urls = try? await NetEaseAPI.shared.songURLs(ids: [song.id], level: quality.neteaseLevel)
            return urls?[song.id]
        }
    }
}
