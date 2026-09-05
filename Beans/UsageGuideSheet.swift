import SwiftUI

struct UsageGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, icon: String, lines: [String])] = [
        (
            "应用简介",
            "music.note.house.fill",
            ["Music 是一款聚合网易云音乐、QQ 音乐与酷狗音乐歌单同步能力的第三方音乐播放器客户端，仅供个人学习研究使用。"]
        ),
        (
            "多平台切换",
            "arrow.left.arrow.right",
            ["首页和搜索保留网易云 / QQ 音乐入口；音乐库可同步网易云、QQ 音乐与酷狗云端歌单。"]
        ),
        (
            "账号服务",
            "person.crop.circle.badge.checkmark",
            ["「我的」页面可统一管理账号登录。登录后会同步对应平台歌单与账号状态。"]
        ),
        (
            "播放体验",
            "play.circle.fill",
            ["全屏播放器支持歌词、进度跳转、倍速、定时关闭、循环模式与音质选择。歌词不同步时可在播放器设置中微调偏移。"]
        ),
        (
            "个性化定制",
            "paintpalette.fill",
            ["支持自定义壁纸、主题色、歌词样式与底部布局。"]
        )
    ]

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: section.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.beansAmber)
                                    Text(section.title)
                                        .font(BeansFont.appFont(14, .bold))
                                        .foregroundStyle(Color.beansLabel)
                                }
                                ForEach(section.lines, id: \.self) { line in
                                    Text(line)
                                        .font(BeansFont.appFont(12.5))
                                        .foregroundStyle(Color.beansLabel.opacity(0.85))
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .beansCardShadow(radius: 8, y: 3)
                        }
                        Text("Music · 仅供学习交流 · 音乐版权归各平台所有 · 酷狗音乐名称及图标归酷狗音乐 / 腾讯音乐娱乐相关权利方所有")
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("软件使用说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.large]))
    }
}
