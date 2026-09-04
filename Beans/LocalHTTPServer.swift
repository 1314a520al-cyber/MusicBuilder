import Foundation
import Network

/// 极简本地 HTTP 服务器，用于服务 web 资源
/// 这样可以直接使用原始构建产物（绝对路径、crossorigin 都能正常工作）
class LocalHTTPServer {
    static let shared = LocalHTTPServer()
    
    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    private var webRootURL: URL?
    
    private init() {}
    
    /// 启动服务器，服务指定目录
    func start(servingDirectory directory: URL) throws -> UInt16 {
        self.webRootURL = directory
        
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: params, on: .any)
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener?.start(queue: .global(qos: .userInitiated))
        
        // 等待端口分配
        let semaphore = DispatchSemaphore(value: 0)
        listener?.stateUpdateHandler = { state in
            if case .ready = state {
                semaphore.signal()
            }
        }
        semaphore.wait()
        
        port = listener?.port?.rawValue ?? 0
        print("[LocalHTTPServer] Started on port \(port), serving: \(directory.path)")
        return port
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        // 读取请求
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            
            // 解析 HTTP 请求
            if let request = String(data: data, encoding: .utf8) {
                let lines = request.components(separatedBy: "\r\n")
                if let firstLine = lines.first {
                    let parts = firstLine.components(separatedBy: " ")
                    if parts.count >= 2, parts[0] == "GET" {
                        var path = parts[1]
                        // 去掉查询参数
                        if let qIndex = path.firstIndex(of: "?") {
                            path = String(path[..<qIndex])
                        }
                        // 根路径返回 index.html
                        if path == "/" || path.isEmpty {
                            path = "/index.html"
                        }
                        self.serveFile(path: path, connection: connection)
                        return
                    }
                }
            }
            
            // 不支持的请求，返回 404
            self.sendResponse(connection: connection, statusCode: 404, body: Data("Not Found".utf8), contentType: "text/plain")
        }
    }
    
    private func serveFile(path: String, connection: NWConnection) {
        guard let webRoot = webRootURL else {
            sendResponse(connection: connection, statusCode: 500, body: Data("Server Error".utf8), contentType: "text/plain")
            return
        }
        
        // 安全检查：防止路径遍历
        let safePath = path.replacingOccurrences(of: "..", with: "")
        let fileURL = webRoot.appendingPathComponent(safePath)
        
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            sendResponse(connection: connection, statusCode: 404, body: Data("Not Found: \(path)".utf8), contentType: "text/plain")
            return
        }
        
        let contentType = mimeType(for: fileURL.pathExtension)
        sendResponse(connection: connection, statusCode: 200, body: data, contentType: contentType)
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: Data, contentType: String) {
        let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        response += "Content-Type: \(contentType)\r\n"
        response += "Content-Length: \(body.count)\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"
        
        var responseData = Data(response.utf8)
        responseData.append(body)
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "application/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "eot": return "application/vnd.ms-fontobject"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "ogg": return "audio/ogg"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain; charset=utf-8"
        case "xml": return "application/xml; charset=utf-8"
        case "wasm": return "application/wasm"
        default: return "application/octet-stream"
        }
    }
}
