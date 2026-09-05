import SwiftUI
import MessageUI

// MARK: - 问题反馈页面

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackType = 0
    @State private var feedbackText = ""
    @State private var contactInfo = ""
    @State private var showSuccess = false
    @State private var showMailComposer = false
    @State private var mailSubject = ""
    @State private var mailBody = ""
    
    let types = ["功能建议", "Bug反馈", "播放问题", "音源问题", "其他"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                List {
                    Section("反馈类型") {
                        Picker("类型", selection: $feedbackType) {
                            ForEach(0..<types.count, id: \.self) { idx in
                                Text(types[idx]).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Section("问题描述") {
                        TextEditor(text: $feedbackText)
                            .frame(minHeight: 120)
                            .font(.subheadline)
                        Text("请详细描述遇到的问题，包括操作步骤、出现的错误提示等")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section("联系方式（选填）") {
                        TextField("邮箱或其他联系方式", text: $contactInfo)
                            .font(.subheadline)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    Section {
                        Button {
                            submitFeedback()
                        } label: {
                            HStack {
                                Spacer()
                                Text("提交反馈")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .alert("提交成功", isPresented: $showSuccess) {
                    Button("确定") { dismiss() }
                } message: {
                    Text("感谢你的反馈，我们会尽快处理！")
                }
                .sheet(isPresented: $showMailComposer) {
                    MailComposerView(
                        toRecipient: "azedix@yeah.net",
                        subject: mailSubject,
                        body: mailBody
                    ) { sent in
                        showMailComposer = false
                        if sent {
                            showSuccess = true
                        }
                    }
                }
            }
            .navigationTitle("意见反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    private func submitFeedback() {
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
        
        // 构建邮件内容，自动发送到 azedix@yeah.net
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        let device = UIDevice.current
        let systemVersion = device.systemVersion
        let modelName = device.model
        let typeName = types[feedbackType]
        let shortDesc = String(feedbackText.prefix(30))
        
        mailSubject = "【Music反馈】\(typeName) - \(shortDesc)"
        mailBody = """
        反馈类型：\(typeName)
        
        问题描述：
        \(feedbackText)
        
        联系方式：\(contactInfo.isEmpty ? "未填写" : contactInfo)
        
        ---
        设备信息：
        设备型号：\(modelName)
        系统版本：iOS \(systemVersion)
        App版本：\(appVersion)
        提交时间：\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .medium))
        """
        
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            // 设备不能发邮件时，只显示成功提示
            showSuccess = true
        }
    }
}

// MARK: - 邮件发送封装

struct MailComposerView: UIViewControllerRepresentable {
    let toRecipient: String
    let subject: String
    let body: String
    var onComplete: (Bool) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([toRecipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onComplete: (Bool) -> Void
        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onComplete(result == .sent)
            controller.dismiss(animated: true)
        }
    }
}
