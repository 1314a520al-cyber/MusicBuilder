import SwiftUI
import WebKit

struct ContentView: View {
    @State private var isLoading = true
    @State private var loadFailed = false
    
    var body: some View {
        ZStack {
            // 主WebView
            WebViewContainer(isLoading: $isLoading, loadFailed: $loadFailed)
                .ignoresSafeArea()
            
            // 启动画面
            if isLoading {
                LaunchScreenView()
                    .transition(.opacity)
            }
            
            // 加载失败提示
            if loadFailed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("加载失败")
                        .font(.headline)
                    Text("请重启应用重试")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadFailed = false
                        isLoading = true
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(32)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 10)
            }
        }
    }
}

// 启动画面
struct LaunchScreenView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.15, green: 0.12, blue: 0.25), Color(red: 0.1, green: 0.08, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 56))
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1.0 : 0.8)
                    .opacity(animate ? 1.0 : 0.5)
                
                Text("易创")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("AI 网文创作助手")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding(.top, 20)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // 注入 Tauri Mock 脚本
        if let mockURL = Bundle.main.url(forResource: "TauriMock", withExtension: "js"),
           let mockScript = try? String(contentsOf: mockURL) {
            let userScript = WKUserScript(
                source: mockScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(userScript)
        }
        
        // 允许 JavaScript
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.preferences.javaScriptEnabled = true
        
        // 媒体播放配置
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // 进程池复用（提升性能）
        config.processPool = WKProcessPool()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) EasyWriting/1.0"
        
        // 设置导航代理
        webView.navigationDelegate = context.coordinator
        
        // 加载本地 index.html
        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            let baseURL = indexURL.deletingLastPathComponent()
            webView.loadFileURL(indexURL, allowingReadAccessTo: baseURL)
        } else {
            loadFailed = true
            isLoading = false
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewContainer
        
        init(_ parent: WebViewContainer) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.4)) {
                    self.parent.isLoading = false
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.loadFailed = true
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.loadFailed = true
            parent.isLoading = false
        }
    }
}
