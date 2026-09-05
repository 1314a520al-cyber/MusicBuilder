import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject var store: DataStore
    @State private var showAddBook = false
    @State private var showTrash = false
    @State private var newBookTitle = ""
    @State private var searchText = ""

    var filteredBooks: [Book] {
        if searchText.isEmpty { return store.activeBooks }
        return store.activeBooks.filter { $0.title.contains(searchText) || $0.author.contains(searchText) }
    }

    var body: some View {
        List {
            if store.activeBooks.isEmpty {
                emptyState
            } else {
                ForEach(filteredBooks) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookRow(book: book)
                    }
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        store.deleteBook(filteredBooks[idx].id)
                    }
                }
            }
        }
        .navigationTitle("书架")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索作品")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showAddBook = true }) {
                        Label("新建作品", systemImage: "plus")
                    }
                    Button(action: { showTrash = true }) {
                        Label("回收站", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddBook) {
            addBookSheet
        }
        .sheet(isPresented: $showTrash) {
            TrashView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("还没有作品")
                .font(.title2)
                .foregroundColor(.gray)
            Button("创建第一部作品") {
                showAddBook = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .listRowBackground(Color.clear)
    }

    private var addBookSheet: some View {
        NavigationStack {
            Form {
                Section("作品信息") {
                    TextField("书名", text: $newBookTitle)
                }
            }
            .navigationTitle("新建作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAddBook = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        if !newBookTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.addBook(Book(title: newBookTitle.trimmingCharacters(in: .whitespaces)))
                            newBookTitle = ""
                            showAddBook = false
                        }
                    }
                    .disabled(newBookTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            if let data = book.coverData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 70)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 50, height: 70)
                    .overlay(
                        Text(book.title.prefix(1))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    )
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text("\(book.chapters.count) 章 · \(book.totalWords) 字")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct TrashView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.deletedBooks.isEmpty {
                    Text("回收站为空")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(store.deletedBooks) { book in
                        HStack {
                            Text(book.title)
                            Spacer()
                            Button("恢复") {
                                store.restoreBook(book.id)
                            }
                            .foregroundColor(.blue)
                            Button("永久删除") {
                                store.permanentDeleteBook(book.id)
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
