import Foundation
import Network

/// 简单的SMTP客户端，SSL直连网易邮箱，自动发送反馈邮件
final class SMTPClient {
    static let shared = SMTPClient()
    
    private let host = "smtp.yeah.net"
    private let port: UInt16 = 465
    private let username = "azedix@yeah.net"
    private let password = "FK4GgXRDmZAfmwQm"
    private let fromEmail = "azedix@yeah.net"
    
    private init() {}
    
    func send(to recipient: String, subject: String, body: String, completion: @escaping (Bool, Error?) -> Void) {
        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tls)
        var buffer = Data()
        var step = 0
        
        func send(_ command: String) {
            let data = (command + "\r\n").data(using: .utf8)!
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    completion(false, error)
                    connection.cancel()
                }
            })
        }
        
        func readNext() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let error = error {
                    completion(false, error)
                    connection.cancel()
                    return
                }
                if let data = data {
                    buffer.append(data)
                }
                guard let text = String(data: buffer, encoding: .utf8),
                      text.hasSuffix("\r\n") || isComplete else {
                    if !isComplete { readNext() }
                    return
                }
                buffer.removeAll()
                handleResponse(text)
            }
        }
        
        func handleResponse(_ response: String) {
            let lines = response.components(separatedBy: "\r\n").filter { !$0.isEmpty }
            guard let last = lines.last else { return }
            let code = String(last.prefix(3))
            
            switch step {
            case 0:
                guard code == "220" else { fail("连接失败: \(response)"); return }
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
                guard code == "235" else { fail("认证失败: \(response)"); return }
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
                completion(true, nil)
                connection.cancel()
            default:
                break
            }
        }
        
        func fail(_ message: String) {
            completion(false, NSError(domain: "SMTP", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
            connection.cancel()
        }
        
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                readNext()
            } else if case .failed(let err) = state {
                completion(false, err)
                connection.cancel()
            }
        }
        connection.start(queue: .global())
    }
}
