import SwiftUI

struct UISettingsView: View {
    @ObservedObject private var theme = NovelTheme.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ui.hideStats") private var hideStats = false
    @AppStorage("ui.hideDownloadCount") private var hideDownloadCount = false
    @AppStorage("ui.hideSourceCount") private var hideSourceCount = false
    @AppStorage("ui.compactMode") private var compactMode = false
    @AppStorage("ui.showTabLabels") private var showTabLabels = true
    @AppStorage("ui.navBarStyle") private var navBarStyle = 0
    @AppStorage("ui.cardRadius") private var cardRadius = 12.0
    @AppStorage("ui.fontScale") private var fontScale = 1.0
    
    let themes: [(name: String, color: Color)] = [
        ("橙日", .orange),
        ("海蓝", .blue),
        ("翠绿", .green),
        ("紫霞", .purple),
        ("粉红", .pink),
        ("玫红", .red),
        ("青色", .teal),
        ("靛蓝", .indigo),
    ]
    
    var body: some View {
        NavigationStack {
            List {
                // 主题颜色
                Section("主题颜色") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(themes, id: \.name) { t in
                            Button {
                                theme.accentColor = t.color
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(t.color)
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(theme.accentColor == t.color ? Color.primary : Color.clear, lineWidth: 2)
                                                .padding(-4)
                                        )
                                    Text(t.name)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(theme.accentColor == t.color ? t.color.opacity(0.1) : Color.clear)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 文字显示设置
                Section("文字显示") {
                    Toggle("隐藏阅读数据", isOn: $hideStats)
                    Toggle("隐藏下载数量", isOn: $hideDownloadCount)
                    Toggle("隐藏书源数量", isOn: $hideSourceCount)
                    Toggle("紧凑模式（减小间距）", isOn: $compactMode)
                    Toggle("显示导航栏文字", isOn: $showTabLabels)
                }
                
                // 字体大小
                Section("字体大小") {
                    HStack {
                        Text("缩放")
                        Spacer()
                        Text(String(format: "%.0f%%", fontScale * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $fontScale, in: 0.8...1.3, step: 0.05)
                        .tint(theme.accentColor)
                }
                
                // 界面样式
                Section("界面样式") {
                    HStack {
                        Text("卡片圆角")
                        Spacer()
                        Text("\(Int(cardRadius))px")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $cardRadius, in: 4...24, step: 2)
                        .tint(theme.accentColor)
                    
                    Picker("导航栏样式", selection: $navBarStyle) {
                        Text("默认").tag(0)
                        Text("大标题").tag(1)
                        Text("内联").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                

            }
            .navigationTitle("UI设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
