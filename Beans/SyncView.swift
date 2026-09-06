import SwiftUI

// MARK: - 同步设置页面

struct SyncView: View {
    @StateObject private var sync = SyncManager.shared
    @StateObject private var theme = ThemeStore.shared
    @State private var showPassword = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                List {
                    // 同步状态
                    Section {
                        HStack {
                            Image(systemName: sync.isSyncing ? "arrow.triangle.2.circlepath" : "cloud.fill")
                                .foregroundColor(sync.isSyncing ? .orange : theme.accent.highlight)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sync.isSyncing ? "同步中..." : (sync.isEnabled ? "已启用同步" : "未启用同步"))
                                    .font(.headline)
                                if sync.hasSynced {
                                    Text("上次同步：\(formattedDate(sync.lastSyncTime))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if sync.isSyncing {
                                ProgressView()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // 连接配置
                    Section("连接配置") {
                        Toggle("启用歌单同步", isOn: Binding(get: { sync.isEnabled }, set: { sync.isEnabled = $0 }))
                            .tint(theme.accent.highlight)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("同步地址")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("https://your-server.com/sync/xxx", text: Binding(get: { sync.serverURL }, set: { sync.serverURL = $0 }))
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("连接密码")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                if showPassword {
                                    TextField("输入连接密码", text: Binding(get: { sync.password }, set: { sync.password = $0 }))
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("输入连接密码", text: Binding(get: { sync.password }, set: { sync.password = $0 }))
                                        .textFieldStyle(.roundedBorder)
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("设备名称")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("iOS设备", text: Binding(get: { sync.deviceName }, set: { sync.deviceName = $0 }))
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    // 同步操作
                    Section("同步操作") {
                        Button {
                            Task { _ = await sync.uploadPlaylists() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                                Text("上传歌单到云端")
                                Spacer()
                                if sync.isSyncing { ProgressView() }
                            }
                        }
                        .disabled(sync.isSyncing || sync.serverURL.isEmpty)
                        
                        Button {
                            Task { _ = await sync.downloadPlaylists() }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                                Text("从云端下载歌单")
                                Spacer()
                                if sync.isSyncing { ProgressView() }
                            }
                        }
                        .disabled(sync.isSyncing || sync.serverURL.isEmpty)
                    }
                    
                    // 错误提示
                    if let error = sync.lastError {
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
                    
                    // 同步日志
                    if !sync.syncLog.isEmpty {
                        Section("同步日志") {
                            ForEach(sync.syncLog, id: \.self) { log in
                                Text(log)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Button {
                                sync.clearLog()
                            } label: {
                                Text("清空日志")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // 说明
                    Section("说明") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("上传：将本地歌单和收藏同步到云端", systemImage: "1.circle")
                            Label("下载：从云端导入歌单到本地（跳过同名歌单）", systemImage: "2.circle")
                            Label("兼容洛雪音乐同步服务协议", systemImage: "checkmark.circle")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("歌单同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
