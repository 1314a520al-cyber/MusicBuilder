import SwiftUI

/// 带缓存和占位符的异步图片组件
struct CachedImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var placeholderColor: Color = Color.gray.opacity(0.15)
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    private static let cache = NSCache<NSURL, UIImage>()
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                // 占位符
                Rectangle()
                    .fill(placeholderColor)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray.opacity(0.4)))
                            .opacity(isLoading ? 1 : 0)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            isLoading = false
            return
        }
        
        // 检查缓存
        if let cached = CachedImage.cache.object(forKey: url as NSURL) {
            image = cached
            isLoading = false
            return
        }
        
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let loadedImage = UIImage(data: data) else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            // 存入缓存
            CachedImage.cache.setObject(loadedImage, forKey: url as NSURL)
            DispatchQueue.main.async {
                image = loadedImage
                isLoading = false
            }
        }.resume()
    }
}

/// 圆形封面图片
struct CachedCoverImage: View {
    let url: String?
    var size: CGFloat = 60
    var cornerRadius: CGFloat = 8
    
    var body: some View {
        CachedImage(url: URL(string: url ?? ""), contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}
