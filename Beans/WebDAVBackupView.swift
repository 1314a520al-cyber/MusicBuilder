import SwiftUI

// MARK: - WebDAV 远程备份页面

struct WebDAVBackupView: View {
    @StateObject private var webdav = WebDAVManager.shared
    @StateObject private var theme = ThemeStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showConfig = false
    @State private var serverInput = ""
    @State private var accountInput = ""
    @State private var passwordInput = ""
    @State private var showPassword = false
    @State private var testing = false
    @State private var testResult: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                List {
                    // 配置状态
                    Section {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.75, blue: 0.55), Color(red: 0.10, green: 0.60, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "cat.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("远程备份 · WebDAV")
                                    .font(.headline)
                                Text(webdav.isConfigured ? "已配置：\(webdav.server)" : "未配置，点击下方按钮设置")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // 操作按钮
                    Section {
                        Button {
                            serverInput = webdav.server
                            accountInput = webdav.account
                            passwordInput = webdav.password
                            showConfig = true
                        } label: {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.blue)
                                Text("配置 WebDAV")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button {
                            Task { _ = await webdav.backup() }
                        } label: {
                            HStack {
                                if webdav.isBackingUp {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.green)
                                }
                                Text(webdav.isBackingUp ? "备份中..." : "立即备份")
                                Spacer()
                            }
                        }
                        .disabled(webdav.isBackingUp || !webdav.isConfigured)
                        
                        Button {
                            Task { await webdav.listBackups() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.orange)
                                Text("查看备份 / 恢复")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(!webdav.isConfigured)
                    }
                    
                    // 上次备份
                    if webdav.hasBackup {
                        Section {
                            HStack {
                                Text("上次备份")
                                Spacer()
                                Text(formattedDate(webdav.lastBackup))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 备份文件列表
                    if !webdav.backupFiles.isEmpty {
                        Section("备份文件") {
                            ForEach(webdav.backupFiles) { file in
                                Button {
                                    Task { _ = await webdav.restore(from: file) }
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(file.name)
                                                .font(.subheadline)
                                            Text("点击恢复")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if webdav.isRestoring {
                                            ProgressView()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 错误提示
                    if let error = webdav.lastError {
                        Section {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    // 说明
                    Section("说明") {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("支持坚果云、Nextcloud、群晖等 WebDAV 服务", systemImage: "1.circle")
                            Label("备份内容：歌单、收藏、设置", systemImage: "2.circle")
                            Label("恢复时自动跳过已存在的歌单", systemImage: "3.circle")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("远程备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showConfig) {
                configSheet
            }
        }
    }
    
    // MARK: - 配置弹窗（截图同款样式）
    
    private var configSheet: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 16) {
                // 猫咪图标
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [Color(red: 0.15, green: 0.75, blue: 0.55), Color(red: 0.10, green: 0.60, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                        .shadow(color: Color(red: 0.15, green: 0.75, blue: 0.55).opacity(0.4), radius: 12, x: 0, y: 4)
                    Image(systemName: "cat.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                Text("远程备份 · WebDAV")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // 输入框
                VStack(spacing: 12) {
                    TextField("服务器地址", text: $serverInput)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    TextField("账号", text: $accountInput)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                        .autocapitalization(.none)
                    
                    HStack {
                        if showPassword {
                            TextField("密码", text: $passwordInput)
                                .textFieldStyle(.plain)
                        } else {
                            SecureField("密码", text: $passwordInput)
                                .textFieldStyle(.plain)
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }
                
                // 测试结果
                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(result.contains("成功") ? .green : .red)
                }
                
                // 按钮
                HStack(spacing: 12) {
                    Button {
                        showConfig = false
                    } label: {
                        Text("取消")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(12)
                    }
                    
                    Button {
                        testing = true
                        testResult = nil
                        Task {
                            webdav.server = serverInput
                            webdav.account = accountInput
                            webdav.password = passwordInput
                            webdav.isEnabled = true
                            let ok = await webdav.testConnection()
                            testing = false
                            testResult = ok ? "连接成功！" : (webdav.lastError ?? "连接失败")
                            if ok {
                                try? await Task.sleep(nanoseconds: 800_000_000)
                                showConfig = false
                            }
                        }
                    } label: {
                        Text(testing ? "测试中..." : "保存")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [Color(red: 0.15, green: 0.75, blue: 0.55), Color(red: 0.10, green: 0.60, blue: 0.45)], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                    }
                    .disabled(testing || serverInput.isEmpty || accountInput.isEmpty)
                }
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .padding(.horizontal, 32)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
