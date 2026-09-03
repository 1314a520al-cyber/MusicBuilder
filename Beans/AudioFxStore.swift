import Foundation
import SwiftUI

/// 音效预设（5 段均衡：60 / 230 / 910 / 3600 / 14000 Hz，单位 dB）。
struct AudioEqPreset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bands: [Int]
}

enum AudioFxPresets {
    static let all: [AudioEqPreset] = [
        .init(name: "关闭（平坦）", bands: [0, 0, 0, 0, 0]),
        .init(name: "流行", bands: [-1, 2, 4, 3, 0]),
        .init(name: "摇滚", bands: [5, 3, -1, 3, 5]),
        .init(name: "古典", bands: [4, 2, -1, 2, 4]),
        .init(name: "爵士", bands: [3, 2, 0, 2, 3]),
        .init(name: "人声", bands: [-2, 1, 3, 3, 2]),
        .init(name: "重低音", bands: [7, 5, 1, 0, 1]),
        .init(name: "清亮高音", bands: [-1, 0, 1, 4, 6]),
        .init(name: "电子", bands: [4, 3, 0, 2, 5]),
        .init(name: "现场", bands: [-2, 2, 3, 3, 2]),
        .init(name: "舞曲", bands: [5, 4, 1, 0, 2]),
        .init(name: "嘻哈", bands: [5, 3, 0, -1, 3]),
        .init(name: "柔和", bands: [1, 2, 2, 1, 0]),
        .init(name: "蓝调", bands: [3, 2, 0, 2, 3]),
        .init(name: "乡村", bands: [2, 2, 1, 2, 3]),
        .init(name: "金属", bands: [6, 4, 0, 3, 5]),
        .init(name: "原声", bands: [3, 2, 1, 2, 3]),
        .init(name: "响度增强", bands: [5, 4, 2, 4, 5]),
        .init(name: "环绕声", bands: [-1, 3, 5, 3, -1]),
        .init(name: "电影", bands: [4, 3, 0, 1, 3]),
        .init(name: "深夜", bands: [1, 0, -2, 2, 4]),
        .init(name: "复古", bands: [2, -1, 1, 0, 4]),
        .init(name: "R&B", bands: [4, 3, 1, 2, 2]),
        .init(name: "雷鬼", bands: [5, 2, -1, 2, 4]),
        .init(name: "朋克", bands: [4, 4, -2, 3, 4]),
        .init(name: "放克", bands: [4, 3, 0, 3, 3]),
        .init(name: "灵魂乐", bands: [3, 3, 1, 2, 2]),
        .init(name: "新世纪", bands: [2, 3, 2, 3, 4]),
        .init(name: "民谣", bands: [2, 2, 2, 1, 1]),
        .init(name: "氛围", bands: [2, 3, 3, 3, 4]),
        .init(name: "电影原声", bands: [3, 2, 1, 3, 5]),
        .init(name: "游戏音乐", bands: [4, 3, 1, 4, 6]),
        .init(name: "播客", bands: [-2, 0, 4, 2, 0]),
        .init(name: "有声书", bands: [-3, -1, 5, 2, -1]),
        .init(name: "车载", bands: [4, 3, 0, 2, 3]),
        .init(name: "耳机优化", bands: [2, 1, 0, 1, 2])
    ]
    static let reverbs = ["无混响", "小房间", "中等房间", "大厅", "中型厅", "大型厅", "板式", "教堂", "洞穴", "竞技场"]
    static let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
}

/// 音效选择持久化（均衡预设 / 重低音 / 混响 / 播放速度）。
final class AudioFxStore: ObservableObject {
    static let shared = AudioFxStore()
    private let defaults = UserDefaults.standard
    @Published var presetIndex: Int { didSet { defaults.set(presetIndex, forKey: kPreset) } }
    @Published var bass: Double { didSet { defaults.set(bass, forKey: kBass) } }
    @Published var reverbIndex: Int { didSet { defaults.set(reverbIndex, forKey: kReverb) } }
    @Published var speed: Double { didSet { defaults.set(speed, forKey: kSpeed) } }

    private let kPreset = "music.fx.preset"
    private let kBass = "music.fx.bass"
    private let kReverb = "music.fx.reverb"
    private let kSpeed = "music.fx.speed"

    var presetName: String {
        AudioFxPresets.all[safe: presetIndex]?.name ?? AudioFxPresets.all[0].name
    }

    private init() {
        let p = AudioFxPresets.all
        presetIndex = defaults.object(forKey: kPreset) as? Int ?? 0
        bass = defaults.object(forKey: kBass) as? Double ?? 0
        reverbIndex = defaults.object(forKey: kReverb) as? Int ?? 0
        speed = defaults.object(forKey: kSpeed) as? Double ?? 1.0
        if presetIndex < 0 || presetIndex >= p.count { presetIndex = 0 }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
