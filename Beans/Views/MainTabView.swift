import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: DataStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BookshelfView()
            }
            .tabItem {
                Label("书架", systemImage: "books.vertical")
            }
            .tag(0)

            NavigationStack {
                InspirationView()
            }
            .tabItem {
                Label("灵感", systemImage: "lightbulb")
            }
            .tag(1)

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("统计", systemImage: "chart.bar")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(3)
        }
        .tint(accentColor)
            .tabViewStyle(.automatic)
    }

    private var accentColor: Color {
        switch store.appSettings.theme {
        case "古韵信笺": return Color(red: 0.6, green: 0.4, blue: 0.2)
        case "森系护眼": return Color(red: 0.3, green: 0.5, blue: 0.35)
        case "暗夜水墨": return Color(red: 0.7, green: 0.7, blue: 0.75)
        default: return Color(red: 0.25, green: 0.35, blue: 0.55)
        }
    }
}
