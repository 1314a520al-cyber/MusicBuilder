import SwiftUI

// MARK: - 快进/后退时间设置

struct SeekIntervalSettingView: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss
    @State private var customText = ""
    @State private var showCustomInput = false
    
    let presetOptions: [Double] = [5, 10, 15, 20, 30, 45, 60]
    
    var body: some View {
        NavigationStack {
            List {
                Section("预设时间") {
                    ForEach(presetOptions, id: \.self) { seconds in
                        Button {
                            player.seekInterval = seconds
                            dismiss()
                        } label: {
                            HStack {
                                Text("\(Int(seconds)) 秒")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if abs(player.seekInterval - seconds) < 0.01 {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section("自定义") {
                    if showCustomInput {
                        HStack {
                            TextField("输入秒数", text: $customText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                            Button("确定") {
                                if let val = Double(customText), val > 0, val <= 300 {
                                    player.seekInterval = val
                                    dismiss()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Button {
                            showCustomInput = true
                        } label: {
                            HStack {
                                Image(systemName: "pencil")
                                Text("自定义秒数（1-300）")
                                Spacer()
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                }
                
                Section {
                    Text("当前设置：快进/后退 \(Int(player.seekInterval)) 秒")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("快进/后退时间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
