import SwiftUI

struct SettingsView: View {
    @ObservedObject private var theme = NovelTheme.shared
    @Environment(\.dismiss) private var dismiss
    @State private var autoDownload = false
    @State private var onlyWifiDownload = true
    @State private var autoAddToShelf = true
    @State private var showReadingProgress = true
    @State private var screenAlwaysOn = true
    @State private var volumeKeyTurnPage = false
    
    var body: some View {
        NavigationStack {
            List {
                // 外观
                Section("外观") {
                    NavigationLink {
                        appThemeView
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(theme.accentColor)
                            Text("主题颜色")
                            Spacer()
                            Text(theme.appThemes[theme.appThemeIndex].name)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $autoAddToShelf) {
                        HStack {
                            Image(systemName: "books.vertical.fill")
                                .foregroundStyle(theme.accentColor)
                            Text("自动加入书架")
                        }
                    }
                }
                
                // 阅读设置
                Section("阅读设置") {
                    HStack {
                        Image(systemName: "textformat.size")
                            .foregroundStyle(theme.accentColor)
                        Text("字体大小")
                        Spacer()
                        Text("\(Int(theme.fontSize))")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $theme.fontSize, in: 12...28, step: 1)
                        .tint(theme.accentColor)
                    
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(theme.accentColor)
                        Text("行间距")
                        Spacer()
                        Text("\(Int(theme.lineSpacing))")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $theme.lineSpacing, in: 2...20, step: 1)
                        .tint(theme.accentColor)
                    
                    Toggle(isOn: $screenAlwaysOn) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundStyle(theme.accentColor)
                            Text("屏幕常亮")
                        }
                    }
                    
                    Toggle(isOn: $showReadingProgress) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(theme.accentColor)
                            Text("显示阅读进度")
                        }
                    }
                }
                
                // 下载设置
                Section("下载设置") {
                    Toggle(isOn: $onlyWifiDownload) {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundStyle(theme.accentColor)
                            Text("仅WiFi下载")
                        }
                    }
                    
                    Toggle(isOn: $autoDownload) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(theme.accentColor)
                            Text("自动下载更新")
                        }
                    }
                }
                
                // 其他
                Section("其他") {
                    Button {
                        // 检查更新
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(theme.accentColor)
                            Text("检查更新")
                            Spacer()
                            Text("v1.1.0")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        // 清除所有数据
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.red)
                            Text("清除所有数据")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
    
    private var appThemeView: some View {
        List {
            ForEach(Array(theme.appThemes.enumerated()), id: \.offset) { index, themeItem in
                Button {
                    theme.setAppTheme(index)
                } label: {
                    HStack {
                        Circle()
                            .fill(themeItem.color)
                            .frame(width: 30, height: 30)
                        Text(themeItem.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if theme.appThemeIndex == index {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle("主题颜色")
    }
}
