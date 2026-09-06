import Foundation
import Network

/// SMTP客户端，SSL直连网易邮箱，自动发送反馈邮件
final class SMTPClient {
    static let shared = SMTPClient()
    
    private let host = "smtp.yeah.net"
    private let port: UInt16 = 465
    private let username = "azedix@yeah.net"
    private let password = "FK4GgXRDmZAfmwQm"
    private let fromEmail = "azedix@yeah.net"
    
    private init() {}
    
    func send(to recipient: String, subject: String, body: String, completion: @escaping (Bool, Error?) -> Void) {
        // 配置TLS参数，最低TLS 1.2
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: parameters)
        var buffer = Data()
        var step = 0
        var hasCompleted = false  // 确保completion只调用一次
        
        func done(_ success: Bool, _ error: Error?) {
            guard !hasCompleted else { return }
            hasCompleted = true
            completion(success, error)
            connection.cancel()
        }
        
        func send(_ command: String) {
            let data = (command + "\r\n").data(using: .utf8)!
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    done(false, error)
                }
            })
        }
        
        func readNext() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, isComplete, error in
                if let error = error {
                    done(false, error)
                    return
                }
                if let data = data, !data.isEmpty {
                    buffer.append(data)
                }
                // 检查是否收到完整响应（以\r\n结尾，或连接关闭）
                guard let text = String(data: buffer, encoding: .utf8),
                      text.hasSuffix("\r\n") || isComplete else {
                    if !isComplete {
                        readNext()
                    } else {
                        done(false, NSError(domain: "SMTP", code: -1, userInfo: [NSLocalizedDescriptionKey: "连接意外关闭"]))
                    }
                    return
                }
                buffer.removeAll()
                handleResponse(text)
            }
        }
        
        func handleResponse(_ response: String) {
            let lines = response.components(separatedBy: "\r\n").filter { !$0.isEmpty }
            guard let last = lines.last else {
                done(false, NSError(domain: "SMTP", code: -2, userInfo: [NSLocalizedDescriptionKey: "空响应"]))
                return
            }
            let code = String(last.prefix(3))
            
            switch step {
            case 0:
                guard code == "220" else { fail("服务器不欢迎: \(response)"); return }
                step = 1; send("EHLO music.app")
            case 1:
                guard code == "250" else { fail("EHLO失败: \(response)"); return }
                step = 2; send("AUTH LOGIN")
            case 2:
                guard code == "334" else { fail("AUTH失败: \(response)"); return }
                step = 3; send(Data(username.utf8).base64EncodedString())
            case 3:
                guard code == "334" else { fail("用户名失败: \(response)"); return }
                step = 4; send(Data(password.utf8).base64EncodedString())
            case 4:
                guard code == "235" else { fail("认证失败(授权码错误?): \(response)"); return }
                step = 5; send("MAIL FROM:<\(fromEmail)>")
            case 5:
                guard code == "250" else { fail("MAIL FROM失败: \(response)"); return }
                step = 6; send("RCPT TO:<\(recipient)>")
            case 6:
                guard code == "250" else { fail("RCPT TO失败: \(response)"); return }
                step = 7; send("DATA")
            case 7:
                guard code == "354" else { fail("DATA失败: \(response)"); return }
                step = 8
                let df = DateFormatter()
                df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                var msg = "From: \(fromEmail)\r\n"
                msg += "To: \(recipient)\r\n"
                msg += "Subject: \(subject)\r\n"
                msg += "Date: \(df.string(from: Date()))\r\n"
                msg += "MIME-Version: 1.0\r\n"
                msg += "Content-Type: text/plain; charset=UTF-8\r\n"
                msg += "Content-Transfer-Encoding: 8bit\r\n\r\n"
                msg += body
                msg += "\r\n.\r\n"
                send(msg)
            case 8:
                guard code == "250" else { fail("发送失败: \(response)"); return }
                send("QUIT")
                done(true, nil)
            default:
                break
            }
        }
        
        func fail(_ message: String) {
            done(false, NSError(domain: "SMTP", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                readNext()
            case .failed(let err):
                done(false, err)
            default:
                break
            }
        }
        connection.start(queue: .global())
    }
}
