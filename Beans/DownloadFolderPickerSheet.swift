import SwiftUI

/// 下载时选择保存到哪个文件夹
struct DownloadFolderPickerSheet: View {
    @ObservedObject private var store = DownloadStore.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var pendingQuality: DownloadQuality?
    let onSelect: (UUID) -> Void
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        BeansNavigationStack {
            List {
                Section("保存到文件夹") {
                    ForEach(store.folders) { folder in
                        Button {
                            BeansHaptics.tap()
                            onSelect(folder.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(Color.beansAmber)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.name)
                                        .font(BeansFont.appFont(15))
                                        .foregroundStyle(Color.beansLabel)
                                    Text("\(folder.songCount) 首")
                                        .font(BeansFont.appFont(11))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer()
                                if store.currentFolderID == folder.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.beansAmber)
                                }
                            }
                        }
                    }
                }
                Button {
                    showCreate = true
                } label: {
                    Label("新建文件夹", systemImage: "folder.badge.plus")
                        .foregroundStyle(Color.beansAmber)
                }
            }
            .navigationTitle("选择文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        pendingQuality = nil
                        dismiss()
                    }
                }
            }
            .alert("新建文件夹", isPresented: $showCreate) {
                TextField("文件夹名称", text: $newName)
                Button("取消", role: .cancel) { newName = "" }
                Button("创建") {
                    let folder = store.createFolder(named: newName)
                    newName = ""
                    onSelect(folder.id)
                    dismiss()
                }
            }
        }
    }
}
