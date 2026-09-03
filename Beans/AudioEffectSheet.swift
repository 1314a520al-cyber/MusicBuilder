import SwiftUI

/// 音效面板：均衡器预设、重低音、混响、播放速度。
struct AudioEffectSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var fx = AudioFxStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            List {
                Section("均衡器") {
                    ForEach(Array(AudioFxPresets.all.enumerated()), id: \.element.id) { idx, preset in
                        Button {
                            fx.presetIndex = idx
                            BeansHaptics.tap()
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .font(BeansFont.appFont(15))
                                    .foregroundStyle(Color.beansLabel)
                                Spacer()
                                if fx.presetIndex == idx {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.beansAmber)
                                }
                            }
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("重低音增强")
                                .font(BeansFont.appFont(15))
                            Spacer()
                            Text("\(Int(fx.bass * 100))%")
                                .font(BeansFont.appFont(13))
                                .foregroundStyle(Color.beansComment)
                        }
                        Slider(value: $fx.bass, in: 0...1)
                            .tint(Color.beansAmber)
                    }
                } header: {
                    Text("低音")
                } footer: {
                    Text("搭配「重低音」均衡预设效果更明显")
                }

                Section("混响") {
                    Picker("混响", selection: $fx.reverbIndex) {
                        ForEach(Array(AudioFxPresets.reverbs.enumerated()), id: \.offset) { i, name in
                            Text(name).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Picker("播放速度", selection: Binding(
                        get: { AudioFxPresets.speeds.firstIndex(of: fx.speed) ?? 1 },
                        set: { i in
                            let v = AudioFxPresets.speeds[safe: i] ?? 1.0
                            fx.speed = v
                            player.setRate(v)
                        }
                    )) {
                        ForEach(Array(AudioFxPresets.speeds.enumerated()), id: \.offset) { i, v in
                            Text(String(format: "%.2gx", v)).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("速度")
                } footer: {
                    Text("均衡预设会被记住；播放速度即时生效")
                }
            }
            .navigationTitle("音效")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
