import SwiftUI

struct ReadingSettingsView: View {
    @ObservedObject private var theme = NovelTheme.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("字体大小") {
                    HStack {
                        Text("字号")
                        Spacer()
                        Text("\(Int(theme.fontSize))")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $theme.fontSize, in: 12...28, step: 1)
                }
                
                Section("行间距") {
                    HStack {
                        Text("行距")
                        Spacer()
                        Text("\(Int(theme.lineSpacing))")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $theme.lineSpacing, in: 2...20, step: 1)
                }
                
                Section("阅读背景") {
                    ForEach(Array(theme.bgThemes.enumerated()), id: \.offset) { index, themeItem in
                        Button {
                            theme.setBgTheme(index)
                        } label: {
                            HStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(themeItem.bg)
                                    .frame(width: 40, height: 30)
                                    .overlay {
                                        Text("文")
                                            .font(.system(size: 12))
                                            .foregroundStyle(themeItem.text)
                                    }
                                Text(themeItem.name)
                                Spacer()
                                if theme.bgColor == themeItem.bg {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.orange)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
