import Foundation

/// 崩溃日志：捕获异常和信号，写入调用栈
enum CrashLogger {
    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            let msg = "EXCEPTION: \(exception.name)\n\(exception.reason ?? "no reason")\n\(exception.callStackSymbols.joined(separator: "\n"))\n---\n"
            writeLog(msg)
        }
        signal(SIGABRT, crashSignalHandler)
        signal(SIGSEGV, crashSignalHandler)
        signal(SIGBUS, crashSignalHandler)
        signal(SIGTRAP, crashSignalHandler)
        signal(SIGILL, crashSignalHandler)
    }
}

private func crashSignalHandler(_ sig: Int32) {
    // 用 backtrace 抓调用栈（async-safe）
    let msg = "SIGNAL: \(sig)\n\(Thread.callStackSymbols.joined(separator: "\n"))\n---\n"
    writeLog(msg)
    signal(sig, SIG_DFL)
    raise(sig)
}

private func writeLog(_ msg: String) {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    guard let doc = paths.first else { return }
    let file = doc.appendingPathComponent("crash_log.txt")
    let data = msg.data(using: .utf8) ?? Data()
    if let handle = try? FileHandle(forWritingTo: file) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: file)
    }
}
