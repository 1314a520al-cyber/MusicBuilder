import SwiftUI
import WebKit

struct ContentView: View {
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            WebViewRepresentable(isLoading: $isLoading, showError: $showError, errorMessage: $errorMessage)
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
            
            if isLoading {
                LoadingView()
                    .transition(.opacity)
            }
            
            if showError {
                ErrorView(errorMessage: errorMessage)
            }
        }
        .ignoresSafeArea()
    }
}

struct LoadingView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.06, blue: 0.15).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1.0 : 0.85)
                Text("易创").font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("正在加载...").font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { animate.toggle() } }
    }
}

struct ErrorView: View {
    let errorMessage: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundColor(.orange)
            Text("加载失败").font(.headline)
            ScrollView { Text(errorMessage).font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal) }
                .frame(maxHeight: 150)
        }
        .padding(24).background(Color(UIColor.systemBackground)).cornerRadius(12).shadow(radius: 8).padding()
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // 1. 注入 Tauri Mock（文档开始前）
        if let mockURL = Bundle.main.url(forResource: "TauriMock", withExtension: "js"),
           let mockScript = try? String(contentsOf: mockURL) {
            let userScript = WKUserScript(source: mockScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            config.userContentController.addUserScript(userScript)
        }
        
        // 2. 注入强制竖屏CSS（文档开始前）
        let portraitCSS = """
        var style = document.createElement('style');
        style.textContent = `
            @media screen and (max-width: 768px) {
                html, body { width: 100% !important; max-width: 100vw !important; overflow-x: hidden !important; }
                #app { width: 100% !important; max-width: 100vw !important; }
                .el-container, .el-aside, .el-main { flex-direction: column !important; width: 100% !important; max-width: 100vw !important; }
                .el-aside { width: 100% !important; min-width: 0 !important; max-height: 50vh !important; overflow-y: auto !important; }
                .el-main { width: 100% !important; padding: 8px !important; }
                .el-menu { width: 100% !important; }
                .el-drawer { width: 85% !important; max-width: 85vw !important; }
                .el-dialog { width: 92% !important; max-width: 92vw !important; margin-top: 5vh !important; }
                .el-table { font-size: 12px !important; }
                .el-button { padding: 8px 12px !important; font-size: 13px !important; }
                .el-input__inner { font-size: 14px !important; }
                .el-textarea__inner { font-size: 14px !important; }
                .el-card { margin: 4px !important; }
                .el-col { padding: 4px !important; }
                .el-row { margin: 0 !important; }
                ::-webkit-scrollbar { width: 4px !important; height: 4px !important; }
            }
            @media (orientation: landscape) and (max-height: 500px) {
                html, body { transform: rotate(0deg) !important; }
            }
            * { -webkit-tap-highlight-color: transparent !important; }
            body { overscroll-behavior: none !important; }
        `;
        document.documentElement.appendChild(style);
        """
        let cssScript = WKUserScript(source: portraitCSS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(cssScript)
        
        // 3. 视口设置
        let viewportScript = WKUserScript(
            source: "var meta = document.createElement('meta'); meta.name='viewport'; meta.content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover'; document.getElementsByTagName('head')[0].appendChild(meta);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(viewportScript)
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.preferences.javaScriptEnabled = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor(red: 0.08, green: 0.06, blue: 0.15, alpha: 1.0)
        webView.isOpaque = true
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.configuration.suppressesIncrementalRendering = false
        
        // 加载 web/index.html
        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        } else {
            DispatchQueue.main.async {
                errorMessage = "找不到 index.html\nBundle: \(Bundle.main.bundlePath)"
                showError = true
                isLoading = false
            }
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        init(_ parent: WebViewRepresentable) { self.parent = parent }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 延迟隐藏加载画面（22MB HTML 需要时间解析执行）
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.4)) { self.parent.isLoading = false }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.errorMessage = error.localizedDescription
                self.parent.showError = true
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.errorMessage = error.localizedDescription
                self.parent.showError = true
                self.parent.isLoading = false
            }
        }
    }
}

// 强制竖屏的 ViewController 包装
extension View {
    func forcePortrait() -> some View {
        self.modifier(PortraitForceModifier())
    }
}

struct PortraitForceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                if #available(iOS 16.0, *) {
                    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                }
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
    }
}
