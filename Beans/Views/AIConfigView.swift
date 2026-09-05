import SwiftUI

struct AIConfigView: View {
    @EnvironmentObject var store: DataStore
    @State private var apiKey: String
    @State private var baseURL: String
    @State private var model: String
    @State private var temperature: Double
    @State private var maxTokens: Int
    @State private var systemPrompt: String
    @State private var showModelPicker = false
    @State private var isTesting = false
    @State private var testResult = ""

    private let presets = [
        ("DeepSeek", "https://api.deepseek.com", "deepseek-chat"),
        ("通义千问", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-turbo"),
        ("智谱清言", "https://open.bigmodel.cn/api/paas/v4", "glm-4"),
        ("Kimi", "https://api.moonshot.cn/v1", "moonshot-v1-8k"),
        ("OpenAI", "https://api.openai.com/v1", "gpt-4o-mini"),
        ("Ollama(本地)", "http://localhost:11434/v1", "llama3"),
    ]

    init() {
        let s = DataStore.shared.aiSettings
        _apiKey = State(initialValue: s.apiKey)
        _baseURL = State(initialValue: s.baseURL)
        _model = State(initialValue: s.model)
        _temperature = State(initialValue: s.temperature)
        _maxTokens = State(initialValue: s.maxTokens)
        _systemPrompt = State(initialValue: s.systemPrompt)
    }

    var body: some View {
        Form {
            Section("预设服务") {
                ForEach(presets, id: \.0) { name, url, mdl in
                    Button(action: {
                        baseURL = url
                        model = mdl
                    }) {
                        HStack {
                            Text(name)
                            Spacer()
                            if baseURL == url {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }

            Section("API 配置") {
                SecureField("API Key（留空使用本地模型）", text: $apiKey)
                TextField("Base URL", text: $baseURL)
                    .autocapitalization(.none)
                TextField("模型名称", text: $model)
                    .autocapitalization(.none)
            }

            Section("参数") {
                VStack(alignment: .leading) {
                    Text("温度：\(String(format: "%.2f", temperature))")
                    Slider(value: $temperature, in: 0...2, step: 0.1)
                }
                Stepper("最大 Token：\(maxTokens)", value: $maxTokens, in: 256...32768, step: 256)
            }

            Section("系统提示词") {
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 100)
            }

            Section {
                Button(action: testConnection) {
                    HStack {
                        if isTesting {
                            ProgressView()
                        }
                        Text("测试连接")
                    }
                }
                .disabled(isTesting)
                if !testResult.isEmpty {
                    Text(testResult)
                        .font(.caption)
                        .foregroundColor(testResult.contains("成功") ? .green : .red)
                }
            }

            Section {
                Button("保存配置") {
                    save()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("AI 模型配置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        var s = store.aiSettings
        s.apiKey = apiKey
        s.baseURL = baseURL
        s.model = model
        s.temperature = temperature
        s.maxTokens = maxTokens
        s.systemPrompt = systemPrompt
        store.aiSettings = s
        store.save()
    }

    private func testConnection() {
        save()
        isTesting = true
        testResult = ""
        Task {
            do {
                let result = try await AIClient.shared.chat(messages: [
                    ["role": "user", "content": "回复\"连接成功\"四个字"]
                ], settings: store.aiSettings)
                await MainActor.run {
                    testResult = "连接成功：\(result.prefix(50))"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "连接失败：\(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}
