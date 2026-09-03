import SwiftUI

struct ModuleContainerView: View {
    let module: ArticleHubView.ArticleModule
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            switch module {
            case .music:
                MusicModuleView()
            case .novel:
                NovelModuleView()
            case .comic:
                ComicModuleView()
            case .audiobook:
                AudiobookModuleView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("首页")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

// 音乐模块 - 复用原有音乐界面
struct MusicModuleView: View {
    var body: some View {
        RootView()
    }
}
