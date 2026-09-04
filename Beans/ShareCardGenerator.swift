import SwiftUI

// MARK: - 分享歌曲卡片生成器

struct ShareCardGenerator {
    /// 生成带封面、歌词高亮和播放链接的分享卡片
    @MainActor
    static func generateCard(song: Song, lyricLine: String? = nil) -> UIImage? {
        let size = CGSize(width: 375, height: 500)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景渐变
            let colors = [
                UIColor(red: 0.15, green: 0.15, blue: 0.25, alpha: 1.0).cgColor,
                UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1.0).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
            
            // 封面
            if let coverURL = song.coverURL, let data = try? Data(contentsOf: coverURL), let cover = UIImage(data: data) {
                let coverSize = CGSize(width: 200, height: 200)
                let coverRect = CGRect(x: (size.width - coverSize.width) / 2, y: 50, width: coverSize.width, height: coverSize.height)
                
                // 封面阴影
                cgContext.setShadow(offset: CGSize(width: 0, height: 8), blur: 20, color: UIColor.black.withAlphaComponent(0.5).cgColor)
                cover.draw(in: coverRect)
                cgContext.setShadow(offset: .zero, blur: 0)
                
                // 封面圆角裁剪
                let path = UIBezierPath(roundedRect: coverRect, cornerRadius: 16)
                path.addClip()
                cover.draw(in: coverRect)
                cgContext.resetClip()
            }
            
            // 歌曲名
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let title = song.name as NSString
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(in: CGRect(x: 20, y: 280, width: size.width - 40, height: 30), withAttributes: titleAttributes)
            
            // 艺术家
            let artistAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.lightGray
            ]
            let artist = song.artists as NSString
            artist.draw(in: CGRect(x: 20, y: 315, width: size.width - 40, height: 20), withAttributes: artistAttributes)
            
            // 歌词高亮（如果有）
            if let lyric = lyricLine, !lyric.isEmpty {
                let lyricAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
                ]
                let lyricText = lyric as NSString
                lyricText.draw(in: CGRect(x: 20, y: 350, width: size.width - 40, height: 40), withAttributes: lyricAttributes)
            }
            
            // 底部播放链接提示
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let footer = "Music · 点击听歌" as NSString
            footer.draw(in: CGRect(x: 20, y: size.height - 40, width: size.width - 40, height: 20), withAttributes: footerAttributes)
            
            // 底部装饰线
            cgContext.setFillColor(UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 0.8).cgColor)
            cgContext.fill(CGRect(x: 20, y: size.height - 50, width: 40, height: 3))
        }
    }
}
