import SwiftUI

/// 启动动画：简洁稳定版，避免复杂动画导致崩溃
struct LaunchAnimationView: View {
    let onFinish: () -> Void

    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var progress: Double = 0
    @State private var fadeOut = false

    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.20),
                    Color(red: 0.15, green: 0.10, blue: 0.30),
                    Color(red: 0.06, green: 0.05, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.35, green: 0.55, blue: 1.0), Color(red: 0.25, green: 0.35, blue: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color(red: 0.4, green: 0.5, blue: 1.0).opacity(0.4), radius: 20, y: 6)

                    Image(systemName: "music.note")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // 标题
                VStack(spacing: 6) {
                    Text("Music")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("发现好音乐")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(textOpacity)

                Spacer()

                // 进度条
                HStack(spacing: 12) {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color(red: 0.4, green: 0.6, blue: 1.0),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))

                    Text("正在启动...")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .opacity(textOpacity)
                .padding(.bottom, 60)
            }
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            textOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
            progress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                fadeOut = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onFinish()
            }
        }
    }
}
