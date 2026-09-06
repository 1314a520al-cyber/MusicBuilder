import SwiftUI

// MARK: - 分享歌曲卡片生成器

struct ShareCardGenerator {
    /// 异步生成带封面、歌词高亮和播放链接的分享卡片
    static func generateCard(song: Song, lyricLine: String? = nil) async -> UIImage? {
        // 异步下载封面（带超时）
        var coverImage: UIImage?
        if let coverURL = song.coverURL {
            do {
                var request = URLRequest(url: coverURL, timeoutInterval: 8)
                let (data, _) = try await URLSession.shared.data(for: request)
                coverImage = UIImage(data: data)
            } catch {
                coverImage = nil
            }
        }
        
        return await generateCardImage(song: song, cover: coverImage, lyricLine: lyricLine)
    }
    
    /// 纯绘制（不做网络请求）
    @MainActor
    private static func generateCardImage(song: Song, cover: UIImage?, lyricLine: String?) -> UIImage {
        let size = CGSize(width: 375, height: 500)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景渐变
            let colors = [
                UIColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0).cgColor,
                UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1.0).cgColor
            ]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
            }
            
            // 封面
            if let cover = cover {
                let coverSize = CGSize(width: 200, height: 200)
                let coverRect = CGRect(x: (size.width - coverSize.width) / 2, y: 50, width: coverSize.width, height: coverSize.height)
                
                cgContext.saveGState()
                let path = UIBezierPath(roundedRect: coverRect, cornerRadius: 16)
                path.addClip()
                cover.draw(in: coverRect)
                cgContext.restoreGState()
                
                // 封面边框
                cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
                cgContext.setLineWidth(1)
                path.stroke()
            } else {
                // 无封面时显示占位
                let coverRect = CGRect(x: (size.width - 200) / 2, y: 50, width: 200, height: 200)
                cgContext.setFillColor(UIColor.white.withAlphaComponent(0.05).cgColor)
                cgContext.fill(coverRect)
                let placeholder = UIImage(systemName: "music.note")?.withTintColor(.white.withAlphaComponent(0.3), renderingMode: .alwaysOriginal)
                placeholder?.draw(in: CGRect(x: size.width/2 - 30, y: 130, width: 60, height: 60))
            }
            
            // 歌曲名
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let title = song.name as NSString
            title.draw(in: CGRect(x: 20, y: 280, width: size.width - 40, height: 30), withAttributes: titleAttributes)
            
            // 艺术家
            let artistAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.lightGray
            ]
            let artist = song.artists as NSString
            artist.draw(in: CGRect(x: 20, y: 315, width: size.width - 40, height: 20), withAttributes: artistAttributes)
            
            // 歌词高亮
            if let lyric = lyricLine, !lyric.isEmpty {
                let lyricAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
                ]
                let lyricText = lyric as NSString
                lyricText.draw(in: CGRect(x: 20, y: 350, width: size.width - 40, height: 60), withAttributes: lyricAttributes)
            }
            
            // 底部装饰线
            cgContext.setFillColor(UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 0.8).cgColor)
            cgContext.fill(CGRect(x: 20, y: size.height - 55, width: 40, height: 3))
            
            // 底部文字
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let footer = "Music · 点击听歌" as NSString
            footer.draw(in: CGRect(x: 20, y: size.height - 40, width: size.width - 40, height: 20), withAttributes: footerAttributes)
        }
    }
}
