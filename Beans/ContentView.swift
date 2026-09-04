import SwiftUI
import WebKit

struct ContentView: View {
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            WebViewContainer(isLoading: $isLoading, loadFailed: $loadFailed, errorMessage: $errorMessage)
                .ignoresSafeArea()
            
            if isLoading {
                LaunchScreenView()
                    .transition(.opacity)
            }
            
            if loadFailed {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("加载失败")
                        .font(.headline)
                    ScrollView {
                        Text(errorMessage.isEmpty ? "未知错误" : errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: 150)
                    Button("重试") {
                        loadFailed = false
                        isLoading = true
                        errorMessage = ""
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

struct LaunchScreenView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red:0.15,green:0.12,blue:0.25), Color(red:0.1,green:0.08,blue:0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 56))
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1.0 : 0.8)
                Text("易创").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                Text("AI 网文创作助手").font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).padding(.top, 20)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { animate.toggle() } }
    }
}

struct WebViewContainer: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool
    @Binding var errorMessage: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // 注入 Tauri Mock
        if let mockURL = Bundle.main.url(forResource: "TauriMock", withExtension: "js"),
           let mockScript = try? String(contentsOf: mockURL) {
            let userScript = WKUserScript(source: mockScript, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            config.userContentController.addUserScript(userScript)
        }
        
        // 注入错误捕获脚本
        let errorCapture = """
        window.addEventListener('error', function(e) {
            window.webkit.messageHandlers.errorHandler.postMessage('Error: ' + e.message + ' at ' + e.filename + ':' + e.lineno);
        });
        window.addEventListener('unhandledrejection', function(e) {
            window.webkit.messageHandlers.errorHandler.postMessage('Unhandled rejection: ' + e.reason);
        });
        """
        config.userContentController.addUserScript(WKUserScript(source: errorCapture, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "errorHandler")
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        config.preferences.javaScriptEnabled = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .white
        webView.isOpaque = true
        webView.scrollView.bounces = true
        webView.navigationDelegate = context.coordinator
        
        // 加载 index.html
        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web") {
            do {
                let html = try String(contentsOf: indexURL, encoding: .utf8)
                let baseURL = indexURL.deletingLastPathComponent()
                webView.loadHTMLString(html, baseURL: baseURL)
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "读取失败: \(error.localizedDescription)"
                    loadFailed = true
                    isLoading = false
                }
            }
        } else {
            // 递归查找
            if let bundlePath = Bundle.main.resourcePath,
               let enumerator = FileManager.default.enumerator(atPath: bundlePath) {
                for case let path as String in enumerator {
                    if path.hasSuffix("index.html") {
                        let url = URL(fileURLWithPath: bundlePath).appendingPathComponent(path)
                        do {
                            let html = try String(contentsOf: url, encoding: .utf8)
                            webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
                        } catch {}
                        break
                    }
                }
            }
            DispatchQueue.main.async {
                errorMessage = "找不到 index.html\nbundle路径: \(Bundle.main.resourcePath ?? "nil")"
                loadFailed = true
                isLoading = false
            }
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer
        init(_ parent: WebViewContainer) { self.parent = parent }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "errorHandler", let msg = message.body as? String {
                DispatchQueue.main.async {
                    self.parent.errorMessage = msg
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.4)) { self.parent.isLoading = false }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.errorMessage = error.localizedDescription
                self.parent.loadFailed = true
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.errorMessage = error.localizedDescription
                self.parent.loadFailed = true
                self.parent.isLoading = false
            }
        }
    }
}
