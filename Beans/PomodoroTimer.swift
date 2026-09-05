import SwiftUI
import Combine

// MARK: - 番茄钟专注模式

final class PomodoroTimer: ObservableObject {
    static let shared = PomodoroTimer()
    
    @Published var isRunning = false
    @Published var isBreak = false
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var completedSessions = 0
    @Published var showSettings = false
    
    var focusDuration: TimeInterval = 25 * 60
    var breakDuration: TimeInterval = 5 * 60
    var longBreakDuration: TimeInterval = 15 * 60
    var sessionsBeforeLongBreak = 4
    
    private var timer: Timer?
    private var endDate: Date?
    
    private init() {
        loadSettings()
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(timeRemaining)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        pause()
        timeRemaining = isBreak ? breakDuration : focusDuration
    }
    
    func skip() {
        completeSession()
    }
    
    private func tick() {
        guard let endDate else { return }
        timeRemaining = max(0, endDate.timeIntervalSinceNow)
        if timeRemaining <= 0 {
            completeSession()
        }
    }
    
    private func completeSession() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        
        if !isBreak {
            completedSessions += 1
            if completedSessions % sessionsBeforeLongBreak == 0 {
                isBreak = true
                timeRemaining = longBreakDuration
            } else {
                isBreak = true
                timeRemaining = breakDuration
            }
            // 专注结束：自动暂停音乐或切换白噪音
            PlayerManager.shared?.togglePlayPause()
        } else {
            isBreak = false
            timeRemaining = focusDuration
        }
        
        // 震动提醒
        BeansHaptics.success()
    }
    
    func formattedTime() -> String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        focusDuration = defaults.double(forKey: "beans.pomodoro.focus")
        if focusDuration == 0 { focusDuration = 25 * 60 }
        breakDuration = defaults.double(forKey: "beans.pomodoro.break")
        if breakDuration == 0 { breakDuration = 5 * 60 }
        longBreakDuration = defaults.double(forKey: "beans.pomodoro.longBreak")
        if longBreakDuration == 0 { longBreakDuration = 15 * 60 }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(focusDuration, forKey: "beans.pomodoro.focus")
        defaults.set(breakDuration, forKey: "beans.pomodoro.break")
        defaults.set(longBreakDuration, forKey: "beans.pomodoro.longBreak")
    }
}

struct PomodoroView: View {
    @StateObject private var pomodoro = PomodoroTimer.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: pomodoro.isBreak 
                        ? [Color(red: 0.2, green: 0.5, blue: 0.4), Color(red: 0.1, green: 0.3, blue: 0.25)]
                        : [Color(red: 0.9, green: 0.4, blue: 0.3), Color(red: 0.7, green: 0.25, blue: 0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text(pomodoro.isBreak ? "休息时间" : "专注中")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    // 圆形进度
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 8)
                            .frame(width: 220, height: 220)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(1 - pomodoro.timeRemaining / (pomodoro.isBreak ? pomodoro.breakDuration : pomodoro.focusDuration)))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: pomodoro.timeRemaining)
                        
                        VStack(spacing: 8) {
                            Text(pomodoro.formattedTime())
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("已完成 \(pomodoro.completedSessions) 个番茄")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    // 控制按钮
                    HStack(spacing: 30) {
                        Button {
                            pomodoro.reset()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                        
                        Button {
                            if pomodoro.isRunning {
                                pomodoro.pause()
                            } else {
                                pomodoro.start()
                            }
                        } label: {
                            Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(Circle().fill(Color.white.opacity(0.3)))
                        }
                        
                        Button {
                            pomodoro.skip()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                    }
                    
                    Text("专注结束自动暂停音乐，帮助你保持专注")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("番茄钟")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}
