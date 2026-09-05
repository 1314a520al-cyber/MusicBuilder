import Foundation

// MARK: - AI 客户端（OpenAI 兼容接口）
class AIClient {
    static let shared = AIClient()
    private init() {}

    struct ChatResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: Message
        }
        struct Message: Decodable {
            let content: String
        }
    }

    struct StreamChunk: Decodable {
        let choices: [DeltaChoice]
        struct DeltaChoice: Decodable {
            let delta: Delta
        }
        struct Delta: Decodable {
            let content: String?
        }
    }

    // MARK: - 普通对话
    func chat(messages: [[String: String]], settings: AISettings) async throws -> String {
        guard let url = URL(string: settings.baseURL.hasSuffix("/chat/completions") ? settings.baseURL : settings.baseURL + "/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "temperature": settings.temperature,
            "max_tokens": settings.maxTokens,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            throw AIError.httpError(statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }

    // MARK: - 流式对话
    func streamChat(messages: [[String: String]], settings: AISettings, onChunk: @escaping (String) -> Void) async throws -> String {
        guard let url = URL(string: settings.baseURL.hasSuffix("/chat/completions") ? settings.baseURL : settings.baseURL + "/v1/chat/completions") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty {
            request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "temperature": settings.temperature,
            "max_tokens": settings.maxTokens,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            throw AIError.httpError(statusCode, "")
        }

        var fullText = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let dataStr = String(line.dropFirst(6))
            guard dataStr != "[DONE]" else { break }
            guard let data = dataStr.data(using: .utf8) else { continue }
            if let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
               let content = chunk.choices.first?.delta.content {
                fullText += content
                await MainActor.run { onChunk(content) }
            }
        }
        return fullText
    }

    // MARK: - 预设功能
    func polish(text: String, settings: AISettings) async throws -> String {
        try await chat(messages: [
            ["role": "system", "content": "你是一个专业的网文编辑，擅长文字润色。保持原意，让文字更流畅、更有感染力。只输出润色后的文字，不要解释。"],
            ["role": "user", "content": "请润色以下文字：\n\(text)"]
        ], settings: settings)
    }

    func expand(text: String, settings: AISettings) async throws -> String {
        try await chat(messages: [
            ["role": "system", "content": "你是一个专业的网文作家，擅长扩写。在保持原意的基础上，增加细节描写、心理活动和环境渲染，让内容更丰满。只输出扩写后的文字。"],
            ["role": "user", "content": "请扩写以下文字：\n\(text)"]
        ], settings: settings)
    }

    func correct(text: String, settings: AISettings) async throws -> String {
        try await chat(messages: [
            ["role": "system", "content": "你是一个专业的文字校对。纠正错别字、语法错误和标点错误，保持原文风格。只输出纠正后的文字。"],
            ["role": "user", "content": "请校对以下文字：\n\(text)"]
        ], settings: settings)
    }

    func continueWriting(context: String, settings: AISettings) async throws -> String {
        try await chat(messages: [
            ["role": "system", "content": "你是一个专业的网文续写助手。根据上下文，自然地续写接下来的内容，保持文风一致，情节连贯。只输出续写的内容。"],
            ["role": "user", "content": "上下文：\n\(context)\n\n请续写："]
        ], settings: settings)
    }

    func generateOutline(topic: String, settings: AISettings) async throws -> String {
        try await chat(messages: [
            ["role": "system", "content": "你是一个专业的网文策划。根据主题，生成一份详细的小说大纲，包括故事梗概、主要人物、世界观设定、分卷大纲。"],
            ["role": "user", "content": "主题：\(topic)\n\n请生成大纲："]
        ], settings: settings)
    }

    func generateNames(category: String, count: Int, settings: AISettings) async throws -> [String] {
        let result = try await chat(messages: [
            ["role": "system", "content": "你是一个取名专家。根据要求生成名字列表，每行一个名字，不要编号，不要解释。"],
            ["role": "user", "content": "请生成\(count)个\(category)名字："]
        ], settings: settings)
        return result.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    func generateSynopsis(bookTitle: String, style: String, settings: AISettings) async throws -> String {
        try await chat(messages: [
            ["role": "system", "content": "你是一个专业的网文简介写手。根据书名和风格要求，生成吸引人的小说简介。"],
            ["role": "user", "content": "书名：\(bookTitle)\n风格：\(style)\n\n请生成简介："]
        ], settings: settings)
    }
}

enum AIError: LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case noAPIKey
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "API 地址无效"
        case .httpError(let code, let msg): return "请求失败 (\(code)): \(msg.prefix(200))"
        case .noAPIKey: return "请先在设置中配置 API Key"
        case .parseError: return "解析响应失败"
        }
    }
}
