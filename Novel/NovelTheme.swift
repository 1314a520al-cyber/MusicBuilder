import SwiftUI

class NovelTheme: ObservableObject {
    static let shared = NovelTheme()
    
    @Published var isDarkMode: Bool = true
    @Published var fontSize: CGFloat = 18
    @Published var lineSpacing: CGFloat = 8
    @Published var bgColor: Color = .black
    @Published var textColor: Color = .white
    @Published var accentColor: Color = .orange
    @Published var appThemeIndex: Int = 0 // 0=橙色, 1=蓝色, 2=绿色, 3=紫色, 4=粉色
    
    let appThemes: [(name: String, color: Color)] = [
        ("橙日", .orange),
        ("海蓝", .blue),
        ("翠绿", .green),
        ("紫霞", .purple),
        ("粉红", .pink),
    ]
    
    // 阅读背景主题
    let bgThemes: [(name: String, bg: Color, text: Color)] = [
        ("夜间", .black, .white),
        ("护眼", Color(red: 0.96, green: 0.95, blue: 0.88), Color(red: 0.2, green: 0.2, blue: 0.15)),
        ("羊皮纸", Color(red: 0.93, green: 0.88, blue: 0.78), Color(red: 0.25, green: 0.2, blue: 0.1)),
        ("清新", Color(red: 0.92, green: 0.97, blue: 0.92), Color(red: 0.15, green: 0.25, blue: 0.15)),
        ("粉色", Color(red: 0.98, green: 0.92, blue: 0.94), Color(red: 0.3, green: 0.15, blue: 0.2)),
    ]
    
    func setAppTheme(_ index: Int) {
        appThemeIndex = index
        accentColor = appThemes[index].color
        UserDefaults.standard.set(index, forKey: "novel.appTheme")
    }
    
    func setBgTheme(_ index: Int) {
        let theme = bgThemes[index]
        bgColor = theme.bg
        textColor = theme.text
        isDarkMode = index == 0
    }
    
    init() {
        let savedTheme = UserDefaults.standard.integer(forKey: "novel.appTheme")
        if savedTheme >= 0 && savedTheme < appThemes.count {
            appThemeIndex = savedTheme
            accentColor = appThemes[savedTheme].color
        }
    }
}

// 液态玻璃背景
struct LiquidGlassBackground: View {
    private var theme: NovelTheme { NovelTheme.shared }
    
    var body: some View {
        ZStack {
            theme.isDarkMode ? Color.black : Color(red: 0.95, green: 0.95, blue: 0.97)
            
            // 渐变光斑
            Circle()
                .fill(theme.accentColor.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(theme.accentColor.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 120, y: 100)
        }
        .ignoresSafeArea()
    }
}

// 玻璃卡片
struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 16
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}
