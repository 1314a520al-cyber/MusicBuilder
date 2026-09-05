import SwiftUI

@main
struct EasyWritingApp: App {
    @StateObject private var store = DataStore.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .preferredColorScheme(store.appSettings.theme == "暗夜水墨" ? .dark : .light)
        }
    }
}
