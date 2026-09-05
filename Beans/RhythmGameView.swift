import SwiftUI

// MARK: - 节奏音游（对齐 kgka_Music_hl：3D透视跑道/圆角矩形音符/预生成FFT频谱/霓虹激光判定线/赛博朋克UI）

enum NoteType {
    case normal, highPitch, hold, bonus
}

struct BeatNote: Identifiable {
    let id = UUID()
    let timeMs: Int
    let endMs: Int
    let xRatio: Double
    let type: NoteType
    var hit = false
    var holdFinished = false
    var judgment: String?
}

/// 谱面生成引擎（对齐 kgka RhythmBeatEngine）
struct RhythmBeatEngine {
    static func generateBeats(songName: String, durationSec: Int) -> [BeatNote] {
        let totalMs = durationSec * 1000
        let seed = abs(songName.hashValue ^ durationSec)
        var rng = seed
        func rand() -> Double {
            rng = (rng &* 1103515245 &+ 12345) & 0x7fffffff
            return Double(rng) / Double(0x7fffffff)
        }
        let bpm = 120 + (seed % 19)
        let beatInterval = 60000 / bpm
        var currentMs = 1500
        var currentX = 0.5
        var direction = 1.0
        var beats: [BeatNote] = []
        while currentMs < totalMs - 2500 {
            currentX += direction * (0.15 + rand() * 0.15)
            if currentX > 0.8 { currentX = 0.8; direction = -1.0 }
            else if currentX < 0.2 { currentX = 0.2; direction = 1.0 }
            let rv = rand()
            var type: NoteType = .normal
            var holdDuration = 0
            if rv > 0.85 { type = .bonus }
            else if rv > 0.70 { type = .hold; holdDuration = 600 + (Int(rand() * 4) * 200) }
            else if rv > 0.45 { type = .highPitch }
            beats.append(BeatNote(timeMs: currentMs, endMs: type == .hold ? currentMs + holdDuration : currentMs, xRatio: currentX, type: type))
            if type == .hold {
                currentMs += holdDuration + beatInterval
            } else {
                if rand() > 0.82 && currentMs + beatInterval / 2 < totalMs {
                    currentX += direction * 0.1
                    currentX = min(0.8, max(0.2, currentX))
                    beats.append(BeatNote(timeMs: currentMs + beatInterval / 2, endMs: currentMs + beatInterval / 2, xRatio: currentX, type: .highPitch))
                }
                currentMs += beatInterval
            }
        }
        return beats
    }

    /// 预生成24频段FFT频谱帧（每20ms一帧，对齐 kgka）
    static func generateSpectrum(beats: [BeatNote], durationSec: Int) -> [[Float]] {
        let totalMs = durationSec * 1000
        let totalFrames = Int(ceil(Double(totalMs) / 20.0))
        var frames: [[Float]] = Array(repeating: Array(repeating: 0, count: 24), count: totalFrames)
        let seed = abs(beats.count ^ durationSec)
        var rng = seed
        func rand() -> Double {
            rng = (rng &* 1103515245 &+ 12345) & 0x7fffffff
            return Double(rng) / Double(0x7fffffff)
        }
        let melodySeed = (0..<24).map { _ in Float(0.15 + rand() * 0.45) }
        // 音符能量映射到频段
        for node in beats {
            let centerFrame = node.timeMs / 20
            if centerFrame < 0 || centerFrame >= totalFrames { continue }
            for f in (centerFrame - 2)...(centerFrame + 9) {
                if f < 0 || f >= totalFrames { continue }
                let dist = abs(f - centerFrame)
                let decay = exp(-Double(dist) * 0.38)
                switch node.type {
                case .normal, .hold:
                    for b in 0...6 { frames[f][b] = min(1, frames[f][b] + Float(decay * 0.88)) }
                case .highPitch:
                    for b in 8...16 { frames[f][b] = min(1, frames[f][b] + Float(decay * 0.92)) }
                case .bonus:
                    for b in 0..<24 { frames[f][b] = min(1, frames[f][b] + Float(decay * 0.96)) }
                }
            }
        }
        // 旋律底噪
        for f in 0..<totalFrames {
            let timeSec = Double(f * 20) / 1000.0
            for b in 0..<24 {
                let baseMelody = abs(sin(timeSec * 2.8 + Double(b) * 0.35)) * Double(melodySeed[b]) * 0.30
                frames[f][b] = max(0.06, min(1, frames[f][b] + Float(baseMelody)))
            }
        }
        return frames
    }
}

struct RhythmGameView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    // 游戏状态
    @State private var beats: [BeatNote] = []
    @State private var spectrumFrames: [[Float]] = []
    @State private var gameTimeMs: Double = 0
    @State private var lastFrame = Date()
    @State private var score = 0
    @State private var combo = 0
    @State private var maxCombo = 0
    @State private var totalHits = 0
    @State private var perfect = 0
    @State private var great = 0
    @State private var good = 0
    @State private var miss = 0
    @State private var feverEnergy: Double = 0
    @State private var feverActive = false
    @State private var feverTimeMs: Double = 0
    @State private var activeHold: BeatNote?
    @State private var lastJudgment: String?
    @State private var lastJudgmentColor = Color.white
    @State private var judgmentScale: CGFloat = 1
    @State private var shakeOffset: CGSize = .zero
    @State private var particles: [Particle] = []
    @State private var shockwaves: [Shockwave] = []
    @State private var stars: [Star] = []
    @State private var paused = false
    @State private var gameOver = false

    private let speedPxPerMs: Double = 0.65
    private let maxFeverMs: Double = 8000
    private let hitLineRatio: CGFloat = 0.70

    private var accuracy: Double {
        if totalHits == 0 { return 100 }
        return min(100, (Double(perfect) * 1.0 + Double(great) * 0.75 + Double(good) * 0.4) / Double(totalHits) * 100)
    }

    private var grade: String {
        let a = accuracy
        if a >= 95 { return "S" }
        if a >= 85 { return "A" }
        if a >= 75 { return "B" }
        if a >= 60 { return "C" }
        return "D"
    }

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            ZStack {
                // 1. 全画布渲染（跑道/频谱/音符/特效）
                Canvas { ctx, size in
                    renderGame(ctx: ctx, size: size)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 2. 顶栏：返回 + 歌曲信息 + 暂停
                topBar(safeTop: safeTop, geo: geo)

                // 3. 霓虹仪表盘（得分/准确率/Fever条）
                dashboard(safeTop: safeTop)

                // 4. Combo 大字
                if combo > 1 {
                    comboDisplay(in: geo.size)
                }

                // 5. 判定文字
                if let j = lastJudgment {
                    judgmentDisplay(j, in: geo.size)
                }

                // 6. 底部提示
                bottomHint(safeBottom: safeBottom)

                // 7. 暂停/结算
                if paused || gameOver { overlayLayer }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color(red: 0.024, green: 0.027, blue: 0.047))
            .offset(shakeOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        handleTap(at: value.startLocation, in: geo.size)
                    }
            )
            .onAppear { setupGame() }
            .onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
                if !paused && !gameOver { updateGame() }
            }
        }
        .ignoresSafeArea(edges: .all)
        .statusBar(hidden: true)
    }

    // MARK: - 渲染

    private func renderGame(ctx: GraphicsContext, size: CGSize) {
        let hitY = size.height * hitLineRatio
        let vanishing = CGPoint(x: size.width * 0.5, y: size.height * 0.12)

        // 星空
        for star in stars {
            let color = feverActive
                ? Color(red: 1, green: 0, blue: 0.5).opacity(0.4 + Double(star.size) * 0.2)
                : Color.white.opacity(0.2 + Double(star.size) * 0.15)
            ctx.fill(Path(ellipseIn: CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)),
                     with: .color(color))
        }

        // 3D 透视跑道（5条线汇聚到消失点）
        let gridColor = feverActive ? Color(red: 1, green: 0, blue: 0.5) : Color(red: 0, green: 1, blue: 0.8)
        let laneRatios: [CGFloat] = [0.12, 0.30, 0.50, 0.70, 0.88]
        for r in laneRatios {
            ctx.stroke(Path { p in
                p.move(to: vanishing)
                p.addLine(to: CGPoint(x: size.width * r, y: size.height))
            }, with: .color(gridColor.opacity(0.12)), lineWidth: 1)
        }

        // 24频段 FFT 频谱
        let barCount = 24
        let barWidth = size.width / CGFloat(barCount)
        let frameIndex = Int(gameTimeMs / 20)
        var spectrum = Array(repeating: Float(0), count: 24)
        if frameIndex >= 0 && frameIndex < spectrumFrames.count {
            spectrum = spectrumFrames[frameIndex]
        }
        for i in 0..<barCount {
            let amplitude = Double(spectrum[i])
            let h = 12 + amplitude * 60
            let x = CGFloat(i) * barWidth
            let y = size.height - CGFloat(h) - 50
            let color: Color
            if feverActive {
                let hue = (Double(i) * 15 + gameTimeMs * 0.0004).truncatingRemainder(dividingBy: 360) / 360
                color = Color(hue: hue, saturation: 0.9, brightness: 1.0)
            } else {
                let t = Double(i) / Double(barCount)
                color = Color(red: 0 * (1-t) + 1 * t, green: 1 * (1-t) + 0 * t, blue: 0.8 * (1-t) + 0.5 * t)
            }
            ctx.fill(Path(CGRect(x: x + 2, y: y, width: barWidth - 4, height: CGFloat(h))),
                     with: .color(color.opacity(feverActive ? 0.55 : 0.30)))
        }

        // 霓虹激光判定线（双层）
        let laserColor = feverActive ? Color(red: 1, green: 0.84, blue: 0) : Color(red: 0, green: 1, blue: 0.8)
        let glowColor = feverActive ? Color(red: 1, green: 0, blue: 0.5) : Color(red: 0, green: 1, blue: 0.8)
        ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: hitY)); p.addLine(to: CGPoint(x: size.width, y: hitY)) },
                   with: .color(glowColor.opacity(0.5)), lineWidth: 10)
        ctx.stroke(Path { p in p.move(to: CGPoint(x: 0, y: hitY)); p.addLine(to: CGPoint(x: size.width, y: hitY)) },
                   with: .color(laserColor), lineWidth: 3.5)

        // 音符
        let platformW: CGFloat = 82
        let platformH: CGFloat = 18
        for node in beats {
            if node.hit && node.judgment == "失误" && node.type != .hold { continue }
            if node.holdFinished { continue }
            let startDelta = Double(node.timeMs) - gameTimeMs
            let startY = hitY - CGFloat(startDelta * speedPxPerMs)
            let nodeX = size.width * CGFloat(node.xRatio)

            // Hold 长键光束
            if node.type == .hold {
                let endDelta = Double(node.endMs) - gameTimeMs
                let endY = hitY - CGFloat(endDelta * speedPxPerMs)
                if endY < size.height + 60 && startY > -60 {
                    let beamTop = min(startY, endY)
                    let beamBottom = max(startY, endY)
                    let beamH = max(10, beamBottom - beamTop)
                    let beamRect = CGRect(x: nodeX - platformW * 0.325, y: beamTop, width: platformW * 0.65, height: beamH)
                    let gradient = Gradient(colors: [Color(red: 0, green: 1, blue: 0.8).opacity(0.8), Color(red: 0.44, green: 0, blue: 1).opacity(0.5)])
                    ctx.fill(Path(roundedRect: beamRect, cornerRadius: 4), with: .linearGradient(gradient, startPoint: CGPoint(x: nodeX, y: beamTop), endPoint: CGPoint(x: nodeX, y: beamBottom)))
                }
            }

            if startY < -40 || startY > size.height + 40 { continue }

            if node.type == .bonus && !node.hit {
                // 金币星芒（圆形+光晕）
                let starR = platformH * 0.9
                ctx.fill(Path(ellipseIn: CGRect(x: nodeX - starR - 4, y: startY - starR - 4, width: (starR + 4) * 2, height: (starR + 4) * 2)),
                         with: .color(Color(red: 1, green: 0.84, blue: 0).opacity(0.35)))
                ctx.fill(Path(ellipseIn: CGRect(x: nodeX - starR, y: startY - starR, width: starR * 2, height: starR * 2)),
                         with: .color(Color(red: 1, green: 0.84, blue: 0)))
            } else {
                // 圆角矩形平台
                let rect = CGRect(x: nodeX - platformW / 2, y: startY - platformH / 2, width: platformW, height: platformH)
                if !node.hit {
                    let haloRect = CGRect(x: nodeX - platformW / 2 - 4, y: startY - platformH / 2 - 4, width: platformW + 8, height: platformH + 8)
                    let haloColor = node.type == .highPitch ? Color(red: 1, green: 0, blue: 0.5) : Color(red: 0, green: 1, blue: 0.8)
                    ctx.fill(Path(roundedRect: haloRect, cornerRadius: 10), with: .color(haloColor.opacity(0.35)))
                }
                let noteColor: Color
                if node.hit { noteColor = Color.white.opacity(0.15) }
                else {
                    switch node.type {
                    case .highPitch: noteColor = Color(red: 1, green: 0, blue: 0.5)
                    case .bonus: noteColor = Color(red: 1, green: 0.84, blue: 0)
                    default: noteColor = Color(red: 0, green: 1, blue: 0.8)
                    }
                }
                ctx.fill(Path(roundedRect: rect, cornerRadius: 9), with: .color(noteColor))
            }
        }

        // 冲击波
        for sw in shockwaves {
            ctx.stroke(Path(ellipseIn: CGRect(x: sw.x - sw.radius, y: sw.y - sw.radius, width: sw.radius * 2, height: sw.radius * 2)),
                       with: .color(sw.color.opacity(sw.alpha)), lineWidth: 3.5)
        }

        // 粒子
        for p in particles {
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - p.size, y: p.y - p.size, width: p.size * 2, height: p.size * 2)),
                     with: .color(p.color.opacity(p.alpha)))
        }
    }

    // MARK: - UI 组件

    private func topBar(safeTop: CGFloat, geo: GeometryProxy) -> some View {
        VStack {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.45)).overlay(Circle().stroke(Color(red: 0, green: 1, blue: 0.8).opacity(0.8), lineWidth: 0.8)))
                }
                .buttonStyle(.plain)

                if let song = player.currentSong {
                    AsyncImage(url: song.coverURL) { phase in
                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                        else { Color.gray.opacity(0.3) }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: Color(red: 0, green: 1, blue: 0.8).opacity(0.6), radius: 8)
                        Text(song.artists)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                } else {
                    Spacer()
                }

                Button {
                    togglePause()
                } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.45)).overlay(Circle().stroke(Color(red: 1, green: 0, blue: 0.5).opacity(0.8), lineWidth: 0.8)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, max(safeTop, 20) + 8)
            Spacer()
        }
    }

    private func dashboard(safeTop: CGFloat) -> some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("得分")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0, green: 1, blue: 0.8))
                        if feverActive {
                            Text("暴走 2X")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color(red: 1, green: 0, blue: 0.5)).shadow(color: Color(red: 1, green: 0, blue: 0.5), radius: 8))
                        }
                    }
                    Text(String(format: "%06d", score))
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundStyle(feverActive ? Color(red: 1, green: 0.84, blue: 0) : .white)
                        .shadow(color: (feverActive ? Color(red: 1, green: 0.84, blue: 0) : Color(red: 0, green: 1, blue: 0.8)).opacity(0.6), radius: 12)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("准确率")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0, blue: 0.5))
                    Text(String(format: "%.1f%%", accuracy))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: Color(red: 1, green: 0, blue: 0.5).opacity(0.6), radius: 12)
                }
            }
            // Fever 能量条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12))
                    Rectangle()
                        .fill(LinearGradient(colors: feverActive
                            ? [Color(red: 1, green: 0, blue: 0.5), Color(red: 1, green: 0.84, blue: 0), Color(red: 0, green: 1, blue: 0.8)]
                            : [Color(red: 0, green: 1, blue: 0.8), Color(red: 1, green: 0, blue: 0.5)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(feverEnergy))
                        .shadow(color: (feverActive ? Color(red: 1, green: 0, blue: 0.5) : Color(red: 0, green: 1, blue: 0.8)).opacity(0.8), radius: 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, max(safeTop, 20) + 60)
    }

    private func comboDisplay(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            Text("\(combo)")
                .font(.system(size: 52, weight: .black, design: .default))
                .italic()
                .foregroundStyle(feverActive ? Color(red: 1, green: 0.84, blue: 0) : Color(red: 0, green: 1, blue: 0.8))
                .shadow(color: (feverActive ? Color(red: 1, green: 0, blue: 0.5) : Color(red: 0, green: 1, blue: 0.8)).opacity(0.8), radius: 20)
                .shadow(color: Color(red: 1, green: 0, blue: 0.5).opacity(0.4), radius: 40)
            Text("连 击")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0, green: 1, blue: 0.8).opacity(0.6), radius: 10)
        }
        .position(x: size.width / 2, y: size.height * 0.26)
    }

    private func judgmentDisplay(_ text: String, in size: CGSize) -> some View {
        Text(text)
            .font(.system(size: 34, weight: .black))
            .foregroundStyle(lastJudgmentColor)
            .scaleEffect(judgmentScale)
            .shadow(color: lastJudgmentColor.opacity(0.8), radius: 24)
            .shadow(color: .black.opacity(0.6), radius: 6)
            .position(x: size.width / 2, y: size.height * 0.54)
    }

    private func bottomHint(safeBottom: CGFloat) -> some View {
        VStack {
            Spacer()
            Text("— 点击屏幕任意位置击打 —")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.24))
                .padding(.bottom, max(safeBottom, 20) + 16)
        }
    }

    private var overlayLayer: some View {
        ZStack {
            Color.black.opacity(0.87)
            VStack(spacing: 0) {
                Text(gameOver ? "关卡完成" : "游戏暂停")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(gameOver ? Color(red: 0, green: 1, blue: 0.8) : .white)
                    .shadow(color: (gameOver ? Color(red: 0, green: 1, blue: 0.8) : .cyan).opacity(0.6), radius: 16)

                if gameOver {
                    Text(grade)
                        .font(.system(size: 80, weight: .black))
                        .foregroundStyle(grade == "S" ? Color(red: 1, green: 0.84, blue: 0) : Color(red: 0, green: 1, blue: 0.8))
                        .shadow(color: (grade == "S" ? Color(red: 1, green: 0.84, blue: 0) : Color(red: 0, green: 1, blue: 0.8)).opacity(0.7), radius: 30)
                        .padding(.top, 8)
                    Text("最终得分: \(score)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                    Text("最高连击: \(maxCombo)")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 4)
                    Text(String(format: "准确率: %.1f%%", accuracy))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("完美: \(perfect) | 优秀: \(great) | 良好: \(good) | 失误: \(miss)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.38))
                        .padding(.top, 4)
                }

                HStack(spacing: 20) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("退出")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        restartGame()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gobackward")
                            Text(gameOver ? "再玩一次" : "重新开始")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0, green: 1, blue: 0.8)).shadow(color: Color(red: 0, green: 1, blue: 0.8), radius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, gameOver ? 22 : 16)
            }
            .padding(26)
            .frame(width: 300)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.063, green: 0.078, blue: 0.133)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(red: 0, green: 1, blue: 0.8).opacity(0.8), lineWidth: 1.2)).shadow(color: Color(red: 0, green: 1, blue: 0.8).opacity(0.4), radius: 24, y: -4))
        }
    }

    // MARK: - 游戏逻辑

    private func setupGame() {
        let songName = player.currentSong?.name ?? "unknown"
        let durationSec = max(Int(player.duration), 60)
        beats = RhythmBeatEngine.generateBeats(songName: songName, durationSec: durationSec)
        spectrumFrames = RhythmBeatEngine.generateSpectrum(beats: beats, durationSec: durationSec)
        gameTimeMs = Double(player.progress * 1000)
        // 中途进入：标记之前的音符
        let currentMs = Int(gameTimeMs)
        for i in beats.indices {
            if beats[i].timeMs < currentMs - 220 {
                beats[i].hit = true
                beats[i].holdFinished = true
            }
        }
        // 星空
        var rng = abs(songName.hashValue ^ durationSec)
        func rand() -> Double {
            rng = (rng &* 1103515245 &+ 12345) & 0x7fffffff
            return Double(rng) / Double(0x7fffffff)
        }
        stars = (0..<40).map { _ in
            Star(x: rand(), y: rand(), speed: 0.001 + rand() * 0.003, size: 1.0 + rand() * 2.5)
        }
        lastFrame = Date()
        if !player.isPlaying { player.togglePlayPause() }
    }

    private func updateGame() {
        guard !paused, !gameOver else { return }
        let now = Date()
        let dt = min(now.timeIntervalSince(lastFrame), 0.05)
        lastFrame = now

        let realAudioMs = player.progress * 1000
        if player.isPlaying {
            gameTimeMs += dt * 1000
            let drift = realAudioMs - gameTimeMs
            if abs(drift) > 500 {
                gameTimeMs = realAudioMs
            } else {
                gameTimeMs += drift * 0.02
            }
        } else {
            gameTimeMs = realAudioMs
        }

        let currentMs = Int(gameTimeMs)

        // Fever 倒计时
        if feverActive {
            feverTimeMs -= dt * 1000
            feverEnergy = min(1, feverTimeMs / maxFeverMs)
            if feverTimeMs <= 0 { feverActive = false; feverEnergy = 0 }
        }

        // 长键持续得分
        if let hold = activeHold {
            if currentMs <= hold.endMs {
                score += 8 * (feverActive ? 2 : 1)
                addFeverEnergy(0.003)
                let hitY = UIScreen.main.bounds.height * hitLineRatio
                spawnParticles(at: CGPoint(x: UIScreen.main.bounds.width * CGFloat(hold.xRatio), y: hitY), count: 2, isSuper: feverActive)
            } else {
                activeHold = nil
                if let idx = beats.firstIndex(where: { $0.id == hold.id }) {
                    beats[idx].holdFinished = true
                }
                score += 300 * (feverActive ? 2 : 1)
                combo += 1
                maxCombo = max(maxCombo, combo)
                addFeverEnergy(0.05)
                showJudgment("完成!", color: Color(red: 0, green: 1, blue: 0.8), scale: 1.3)
                BeansHaptics.medium()
            }
        }

        // MISS 判定
        for i in beats.indices {
            if !beats[i].hit && currentMs - beats[i].timeMs > 220 {
                beats[i].hit = true
                beats[i].judgment = "失误"
                onMiss()
            }
        }

        // 特效更新
        for i in stars.indices {
            stars[i].y += stars[i].speed * (feverActive ? 2.5 : 1.0)
            if stars[i].y > 1 { stars[i].y = 0; stars[i].x = Double.random(in: 0...1) }
        }
        shockwaves = shockwaves.map { var s = $0; s.update(); return s }.filter { !$0.isDead }
        particles = particles.map { var p = $0; p.update(); return p }.filter { !$0.isDead }
        shakeOffset.width *= 0.85
        shakeOffset.height *= 0.85
        judgmentScale = max(1, judgmentScale - CGFloat(dt * 5))

        // 歌曲结束
        let totalMs = player.duration * 1000
        if totalMs > 0 && currentMs >= Int(totalMs) - 500 {
            gameOver = true
            paused = true
            if player.isPlaying { player.togglePlayPause() }
        }
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        guard !paused, !gameOver else { return }
        let currentMs = Int(gameTimeMs)
        var closest: BeatNote?
        var minDelta = 999999
        for node in beats {
            if !node.hit {
                let delta = abs(node.timeMs - currentMs)
                if delta < minDelta { minDelta = delta; closest = node }
            }
        }
        guard let node = closest, minDelta <= 220 else {
            shockwaves.append(Shockwave(x: location.x, y: location.y, color: .white.opacity(0.14), maxRadius: 30))
            BeansHaptics.select()
            return
        }

        let hitY = size.height * hitLineRatio
        let hitPoint = CGPoint(x: size.width * CGFloat(node.xRatio), y: hitY)
        let mult = feverActive ? 2 : 1

        // 找到 index 来修改
        guard let idx = beats.firstIndex(where: { $0.id == node.id }) else { return }
        beats[idx].hit = true
        totalHits += 1

        if node.type == .bonus {
            score += 1000 * mult
            combo += 1; maxCombo = max(maxCombo, combo); perfect += 1
            addFeverEnergy(0.12)
            showJudgment("奖励! +1000", color: Color(red: 1, green: 0.84, blue: 0), scale: 1.5)
            triggerShake(7)
            shockwaves.append(Shockwave(x: hitPoint.x, y: hitPoint.y, color: Color(red: 1, green: 0.84, blue: 0), maxRadius: 100))
            spawnParticles(at: hitPoint, count: 28, isSuper: true)
            BeansHaptics.heavy()
            return
        }

        if node.type == .hold {
            activeHold = beats[idx]
            score += 300 * mult
            combo += 1; maxCombo = max(maxCombo, combo)
            addFeverEnergy(0.04)
            showJudgment("按住!", color: Color(red: 0, green: 1, blue: 0.8), scale: 1.35)
            shockwaves.append(Shockwave(x: hitPoint.x, y: hitPoint.y, color: Color(red: 0, green: 1, blue: 0.8), maxRadius: 75))
            spawnParticles(at: hitPoint, count: 18, isSuper: feverActive)
            BeansHaptics.medium()
            return
        }

        if minDelta <= 60 {
            score += (500 + combo * 10) * mult
            combo += 1; maxCombo = max(maxCombo, combo); perfect += 1
            addFeverEnergy(0.04)
            showJudgment("完美!", color: Color(red: 0, green: 1, blue: 0.8), scale: 1.45)
            triggerShake(8)
            shockwaves.append(Shockwave(x: hitPoint.x, y: hitPoint.y, color: Color(red: 0, green: 1, blue: 0.8), maxRadius: 90))
            spawnParticles(at: hitPoint, count: 22, isSuper: feverActive)
            BeansHaptics.heavy()
        } else if minDelta <= 130 {
            score += (300 + combo * 5) * mult
            combo += 1; maxCombo = max(maxCombo, combo); great += 1
            addFeverEnergy(0.025)
            showJudgment("优秀!", color: Color(red: 1, green: 0.84, blue: 0), scale: 1.25)
            triggerShake(4)
            shockwaves.append(Shockwave(x: hitPoint.x, y: hitPoint.y, color: Color(red: 1, green: 0.84, blue: 0), maxRadius: 65))
            spawnParticles(at: hitPoint, count: 15, isSuper: false)
            BeansHaptics.medium()
        } else if minDelta <= 200 {
            score += 100 * mult
            combo += 1; maxCombo = max(maxCombo, combo); good += 1
            addFeverEnergy(0.015)
            showJudgment("良好", color: Color(red: 0.3, green: 0.93, blue: 0.92), scale: 1.15)
            shockwaves.append(Shockwave(x: hitPoint.x, y: hitPoint.y, color: Color(red: 0.3, green: 0.93, blue: 0.92), maxRadius: 45))
            spawnParticles(at: hitPoint, count: 10, isSuper: false)
            BeansHaptics.light()
        } else {
            onMiss()
        }
    }

    private func addFeverEnergy(_ amount: Double) {
        if feverActive { return }
        feverEnergy = min(1, feverEnergy + amount)
        if feverEnergy >= 1 {
            feverActive = true
            feverTimeMs = maxFeverMs
            triggerShake(12)
            let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
            shockwaves.append(Shockwave(x: center.x, y: center.y, color: Color(red: 0, green: 1, blue: 0.8), maxRadius: 400))
            shockwaves.append(Shockwave(x: center.x, y: center.y, color: Color(red: 1, green: 0, blue: 0.5), maxRadius: 300))
        }
    }

    private func onMiss() {
        combo = 0
        miss += 1
        totalHits += 1
        activeHold = nil
        showJudgment("失误", color: Color(red: 1, green: 0.2, blue: 0.4), scale: 1.35)
        triggerShake(6)
    }

    private func showJudgment(_ text: String, color: Color, scale: CGFloat) {
        lastJudgment = text
        lastJudgmentColor = color
        judgmentScale = scale
    }

    private func triggerShake(_ intensity: Double) {
        shakeOffset = CGSize(width: CGFloat((Double.random(in: 0...1) - 0.5) * intensity * 2),
                             height: CGFloat((Double.random(in: 0...1) - 0.5) * intensity * 2))
    }

    private func spawnParticles(at point: CGPoint, count: Int, isSuper: Bool) {
        let colors: [Color] = [
            Color(red: 0, green: 1, blue: 0.8),
            Color(red: 1, green: 0, blue: 0.5),
            Color(red: 1, green: 0.84, blue: 0),
            Color(red: 0.44, green: 0, blue: 1)
        ]
        for i in 0..<count {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = (isSuper ? 3.5 : 2.0) + Double.random(in: 0...6)
            particles.append(Particle(
                x: point.x, y: point.y,
                vx: cos(angle) * speed, vy: sin(angle) * speed,
                color: colors[i % colors.count],
                size: isSuper ? 4.5 : 3.0
            ))
        }
    }

    private func togglePause() {
        paused.toggle()
        if paused {
            if player.isPlaying { player.togglePlayPause() }
        } else {
            if !player.isPlaying { player.togglePlayPause() }
        }
    }

    private func restartGame() {
        score = 0; combo = 0; maxCombo = 0; totalHits = 0
        perfect = 0; great = 0; good = 0; miss = 0
        feverEnergy = 0; feverActive = false; feverTimeMs = 0
        activeHold = nil; paused = false; gameOver = false
        lastJudgment = nil
        for i in beats.indices {
            beats[i].hit = false
            beats[i].holdFinished = false
            beats[i].judgment = nil
        }
        gameTimeMs = 0
        player.seek(to: 0)
        if !player.isPlaying { player.togglePlayPause() }
    }
}

// MARK: - 特效实体

private struct Particle {
    var x: CGFloat; var y: CGFloat
    var vx: Double; var vy: Double
    var color: Color
    var size: CGFloat
    var alpha: Double = 1.0
    var isDead: Bool { alpha <= 0 }
    mutating func update() {
        x += CGFloat(vx)
        y += CGFloat(vy)
        vx *= 0.94; vy *= 0.94
        alpha -= 0.035
        size = max(0, size - 0.06)
        if alpha < 0 { alpha = 0 }
    }
}

private struct Shockwave {
    var x: CGFloat; var y: CGFloat
    var color: Color
    let maxRadius: Double
    var radius: Double = 10
    var alpha: Double = 1.0
    var isDead: Bool { alpha <= 0 || radius >= maxRadius }
    mutating func update() {
        radius += (maxRadius - radius) * 0.22 + 2
        alpha -= 0.06
        if alpha < 0 { alpha = 0 }
    }
}

private struct Star {
    var x: Double; var y: Double
    var speed: Double; var size: Double
}
