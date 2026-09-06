import SwiftUI

// MARK: - 问题反馈页面（SMTP自动发送到 azedix@yeah.net）

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackType = 0
    @State private var feedbackText = ""
    @State private var contactInfo = ""
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSending = false
    
    let types = ["功能建议", "Bug反馈", "播放问题", "音源问题", "其他"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // 反馈类型
                        sectionHeader("反馈类型")
                        Picker("类型", selection: $feedbackType) {
                            ForEach(0..<types.count, id: \.self) { idx in
                                Text(types[idx]).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        
                        // 问题描述
                        sectionHeader("问题描述")
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $feedbackText)
                                .frame(minHeight: 120)
                                .font(.subheadline)
                            Text("请详细描述遇到的问题，包括操作步骤、出现的错误提示等")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        
                        // 联系方式
                        sectionHeader("联系方式（选填）")
                        TextField("邮箱或其他联系方式", text: $contactInfo)
                            .font(.subheadline)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        
                        // 提交按钮
                        Button {
                            submitFeedback()
                        } label: {
                            HStack {
                                Spacer()
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                    Text("发送中...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                } else {
                                    Text("提交反馈")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 14)
                            .background(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending ? Color.gray : Color.blue)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                        
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("意见反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("发送成功", isPresented: $showSuccess) {
                Button("确定") { dismiss() }
            } message: {
                Text("感谢你的反馈，已发送到开发者邮箱！")
            }
            .alert("发送失败", isPresented: $showError) {
                Button("重试") { submitFeedback() }
                Button("取消", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundColor(.gray)
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func submitFeedback() {
        guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSending = true
        
        // 保存到本地
        let defaults = UserDefaults.standard
        var feedbacks = defaults.array(forKey: "beans.feedbacks") as? [[String: Any]] ?? []
        feedbacks.append([
            "type": types[feedbackType],
            "text": feedbackText,
            "contact": contactInfo,
            "time": Date().timeIntervalSince1970
        ])
        defaults.set(feedbacks, forKey: "beans.feedbacks")
        
        // 构建邮件内容
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        let device = UIDevice.current
        let typeName = types[feedbackType]
        
        let subject = "【Music反馈】\(typeName) - \(String(feedbackText.prefix(30)))"
        let body = """
        反馈类型：\(typeName)
        
        问题描述：
        \(feedbackText)
        
        联系方式：\(contactInfo.isEmpty ? "未填写" : contactInfo)
        
        ---
        设备信息：
        设备型号：\(device.model)
        系统版本：iOS \(device.systemVersion)
        App版本：\(appVersion)
        提交时间：\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))
        """
        
        // SMTP自动发送
        SMTPClient.shared.send(to: "azedix@yeah.net", subject: subject, body: body) { success, error in
            DispatchQueue.main.async {
                isSending = false
                if success {
                    showSuccess = true
                } else {
                    errorMessage = error?.localizedDescription ?? "未知错误，请检查网络后重试"
                    showError = true
                }
            }
        }
    }
}
