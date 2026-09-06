import AVFoundation

/// 真正的音频效果引擎：AVAudioEngine + AVAudioUnitEQ + AVAudioUnitReverb
/// 当用户启用非默认音效时，下载歌曲到临时文件后通过此引擎播放，获得真实音效
final class EffectAudioEngine: ObservableObject {
    static let shared = EffectAudioEngine()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private let reverbNode = AVAudioUnitReverb()
    private var audioFile: AVAudioFile?
    private var playbackRate: Float = 1.0
    private var timer: Timer?

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    var onEnded: (() -> Void)?

    private init() {
        setupEngine()
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(reverbNode)
        // playerNode -> eq -> reverb -> mixer -> output
        engine.connect(playerNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: reverbNode, format: nil)
        engine.connect(reverbNode, to: engine.mainMixerNode, format: nil)
        // 默认 EQ 全直通
        for band in eqNode.bands { band.bypass = true }
        reverbNode.wetDryMix = 0
    }

    // MARK: - EQ 预设
    private let eqGains: [String: [Float]] = [
        "默认":   [0,0,0,0,0,0,0,0,0,0],
        "重低音": [7,5,3,1,0,0,0,0,0,0],
        "流行":   [-1,2,4,4,2,0,-1,-1,0,0],
        "摇滚":   [5,4,2,0,-1,0,2,3,4,5],
        "古典":   [4,3,2,0,-1,-1,0,2,3,4],
        "爵士":   [3,2,1,2,-1,-1,0,1,2,3],
        "电子":   [5,4,0,-2,-3,0,2,4,5,5],
        "人声":   [-2,-1,0,2,4,4,3,2,0,-1],
        "舞曲":   [5,3,0,2,4,4,2,0,3,5],
        "蓝调":   [3,2,1,0,-1,-1,0,1,2,3],
    ]

    func applyEQ(preset: String, bassBoost: Float) {
        // 从 AudioFxStore 获取5频段增益，映射到10频段EQ
        let fx5 = AudioFxPresets.all.first(where: { $0.name == preset })?.bands ?? [0,0,0,0,0]
        // 5频段(60/230/910/3600/14000) -> 10频段(32/64/125/250/500/1k/2k/4k/8k/16k)
        let mapping = [0,0, 1,1, 2,2, 3,3, 4,4]
        for (i, band) in eqNode.bands.enumerated() {
            let g = Float(fx5[mapping[i]])
            // 前3个频段叠加重低音
            let bass = i < 3 ? bassBoost * 8 : 0
            band.gain = g + bass
            band.bypass = false
            band.bandwidth = 1.0
        }
    }

    func resetEQ() {
        for band in eqNode.bands { band.bypass = true }
    }

    // MARK: - 混响
    private let reverbPresets: [AVAudioUnitReverbPreset] = [
        .smallRoom, .mediumRoom, .largeRoom, .mediumHall,
        .largeHall, .plate, .mediumHall2, .cathedral,
        .largeRoom2, .largeHall2
    ]

    /// 应用当前 AudioFxStore 中的所有音效设置
    func applyCurrentEffects() {
        let fx = AudioFxStore.shared
        applyEQ(preset: fx.presetName, bassBoost: Float(fx.bass))
        applyReverb(index: fx.reverbIndex)
    }

    func applyReverb(index: Int) {
        guard index > 0 else {
            reverbNode.wetDryMix = 0
            return
        }
        let preset = reverbPresets[min(index - 1, reverbPresets.count - 1)]
        reverbNode.loadFactoryPreset(preset)
        reverbNode.wetDryMix = 35
    }

    // MARK: - 播放控制
    func play(url: URL, rate: Float = 1.0) {
        stop()
        do {
            audioFile = try AVAudioFile(forReading: url)
            duration = Double(audioFile!.length) / audioFile!.fileFormat.sampleRate
            playbackRate = rate
            try engine.start()
            playerNode.scheduleFile(audioFile!, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    self?.onEnded?()
                }
            }
            playerNode.rate = rate
            playerNode.play()
            isPlaying = true
            startTimer()
        } catch {
            BeansLogger.shared.log("EffectEngine play error: \(error.localizedDescription)", level: .error)
        }
    }

    /// 从指定时间开始播放（切换音效时不从头开始）
    func play(url: URL, fromTime: TimeInterval, rate: Float = 1.0) {
        stop()
        do {
            audioFile = try AVAudioFile(forReading: url)
            duration = Double(audioFile!.length) / audioFile!.fileFormat.sampleRate
            playbackRate = rate
            try engine.start()
            
            if fromTime > 0.5, let af = audioFile {
                let sampleRate = af.fileFormat.sampleRate
                let startFrame = AVAudioFramePosition(fromTime * sampleRate)
                let frameCount = AVAudioFrameCount(af.length - startFrame)
                if frameCount > 0 {
                    playerNode.scheduleSegment(af, startingFrame: startFrame, frameCount: frameCount, at: nil) { [weak self] in
                        DispatchQueue.main.async {
                            self?.isPlaying = false
                            self?.onEnded?()
                        }
                    }
                    currentTime = fromTime
                } else {
                    playerNode.scheduleFile(af, at: nil) { [weak self] in
                        DispatchQueue.main.async {
                            self?.isPlaying = false
                            self?.onEnded?()
                        }
                    }
                }
            } else {
                playerNode.scheduleFile(audioFile!, at: nil) { [weak self] in
                    DispatchQueue.main.async {
                        self?.isPlaying = false
                        self?.onEnded?()
                    }
                }
            }
            
            playerNode.rate = rate
            playerNode.play()
            isPlaying = true
            startTimer()
        } catch {
            BeansLogger.shared.log("EffectEngine play error: \(error.localizedDescription)", level: .error)
        }
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
        stopTimer()
    }

    func resume() {
        playerNode.play()
        playerNode.rate = playbackRate
        isPlaying = true
        startTimer()
    }

    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }
        let sampleRate = audioFile.fileFormat.sampleRate
        let frame = min(max(AVAudioFramePosition(time * sampleRate), 0), audioFile.length - 1)
        let frameCount = max(AVAudioFrameCount(audioFile.length - frame), 1)
        playerNode.stop()
        playerNode.scheduleSegment(audioFile, startingFrame: frame, frameCount: frameCount, at: nil)
        playerNode.play()
        playerNode.rate = playbackRate
        currentTime = time
        isPlaying = true
        startTimer()
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
        audioFile = nil
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let nodeTime = self.playerNode.lastRenderTime,
                  let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) else { return }
            let time = Double(playerTime.sampleTime) / playerTime.sampleRate
            DispatchQueue.main.async { self.currentTime = time }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
