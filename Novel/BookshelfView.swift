import SwiftUI

struct BookshelfView: View {
    @ObservedObject private var theme = NovelTheme.shared
    @State private var showAddBook = false
    @State private var showSourceManager = false
    @State private var isGridView = true
    @State private var showManage = false
    
    // 示例书架数据
    @State private var books: [ShelfBook] = [
        ShelfBook(title: "斗破苍穹", author: "天蚕土豆", coverUrl: "", lastRead: "第100章 陨落心炎", progress: 0.35),
        ShelfBook(title: "完美世界", author: "辰东", coverUrl: "", lastRead: "第50章 鲲鹏宝术", progress: 0.18),
        ShelfBook(title: "遮天", author: "辰东", coverUrl: "", lastRead: "第200章 圣体大成", progress: 0.62),
        ShelfBook(title: "凡人修仙传", author: "忘语", coverUrl: "", lastRead: "第300章 元婴期", progress: 0.45),
        ShelfBook(title: "诡秘之主", author: "爱潜水的乌贼", coverUrl: "", lastRead: "第150章 愚者", progress: 0.28),
        ShelfBook(title: "大奉打更人", author: "卖报小郎君", coverUrl: "", lastRead: "第80章 银锣", progress: 0.12),
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if books.isEmpty {
                    emptyShelfView
                } else {
                    if isGridView {
                        gridShelfView
                    } else {
                        listShelfView
                    }
                }
            }
            .navigationTitle("书架")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isGridView.toggle()
                        } label: {
                            Label(isGridView ? "列表视图" : "网格视图", systemImage: isGridView ? "list.bullet" : "square.grid.2x2")
                        }
                        Button {
                            showManage.toggle()
                        } label: {
                            Label("管理书架", systemImage: "slider.horizontal.3")
                        }
                        Button {
                            showSourceManager = true
                        } label: {
                            Label("书源管理", systemImage: "externaldrive.connected.to.line.below")
                        }
                        Divider()
                        Button {
                            showAddBook = true
                        } label: {
                            Label("添加书籍", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
            .sheet(isPresented: $showSourceManager) {
                SourceManagerView()
            }
        }
    }
    
    // 空书架
    private var emptyShelfView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("书架空空如也")
                .font(.title2)
                .foregroundStyle(.gray)
            Text("去发现页找几本喜欢的书吧")
                .font(.subheadline)
                .foregroundStyle(.gray.opacity(0.7))
            Button {
                showAddBook = true
            } label: {
                Text("添加书籍")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(theme.accentColor)
                    .cornerRadius(20)
            }
        }
        .padding(.top, 100)
    }
    
    // 网格书架
    private var gridShelfView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
            ForEach(books) { book in
                BookGridItem(book: book)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
    
    // 列表书架
    private var listShelfView: some View {
        LazyVStack(spacing: 0) {
            ForEach(books) { book in
                BookListItem(book: book)
                Divider()
                    .padding(.leading, 80)
            }
        }
        .padding(.horizontal, 16)
    }
}

// 书架书籍模型
struct ShelfBook: Identifiable {
    let id = UUID()
    let title: String
    let author: String
    let coverUrl: String
    let lastRead: String
    let progress: Double
}

// 网格书籍项
struct BookGridItem: View {
    let book: ShelfBook
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 封面
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .aspectRatio(3/4, contentMode: .fit)
                
                Text(book.title.prefix(2))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(alignment: .bottom) {
                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Color.black.opacity(0.3)
                        Color.white.opacity(0.8)
                            .frame(width: geo.size.width * book.progress)
                    }
                }
                .frame(height: 3)
            }
            
            Text(book.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.white)
            
            Text(book.lastRead)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(.gray)
        }
    }
}

// 列表书籍项
struct BookListItem: View {
    let book: ShelfBook
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 66)
                
                Text(book.title.prefix(2))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                
                Text(book.author)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                
                Text(book.lastRead)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray.opacity(0.8))
                
                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Color.gray.opacity(0.3)
                        Color.blue
                            .frame(width: geo.size.width * book.progress)
                    }
                }
                .frame(height: 3)
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// 添加书籍页面
struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var theme = NovelTheme.shared
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("在发现页搜索并添加书籍到书架")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .padding()
                Spacer()
            }
            .navigationTitle("添加书籍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
