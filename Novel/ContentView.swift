import SwiftUI

struct ContentView: View {
    @ObservedObject private var theme = NovelTheme.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 书架
            BookshelfView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "books.vertical.fill" : "books.vertical")
                    Text("书架")
                }
                .tag(0)
            
            // 发现
            DiscoveryView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "safari.fill" : "safari")
                    Text("发现")
                }
                .tag(1)
            
            // 我的
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.fill" : "person")
                    Text("我的")
                }
                .tag(2)
        }
        .tint(theme.accentColor)
        .preferredColorScheme(.dark)
    }
}

// 发现页（整合书城和搜索）
struct DiscoveryView: View {
    @ObservedObject private var theme = NovelTheme.shared
    @State private var showSearch = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 搜索栏
                    Button {
                        showSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.gray)
                            Text("搜索小说、作者")
                                .foregroundStyle(.gray)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    
                    // 书城内容
                    BookCityContent()
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
        }
    }
}

// 书城内容（提取出来，在发现页中使用）
struct BookCityContent: View {
    var body: some View {
        BookCityView()
            .frame(height: 800)
    }
}
