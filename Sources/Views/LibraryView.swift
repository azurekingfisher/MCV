import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedBookForNavigation: ComicBook?
    
    // 무채색 배경
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 140, maximum: 200), spacing: 20), count: max(1, viewModel.columnsCount))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                if viewModel.books.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("만화책이 있는 폴더(Zip)를 선택해주세요.")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Button("폴더 선택") {
                            viewModel.selectFolder()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                } else {
                    GeometryReader { geometry in
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVGrid(columns: gridColumns, spacing: 30) {
                                    ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
                                        BookItemView(book: book, viewModel: viewModel, isSelected: index == viewModel.selectedIndex)
                                            .id(book.id)
                                            .onTapGesture {
                                                viewModel.selectedIndex = index
                                                viewModel.openSelectedBookAction?(book)
                                            }
                                    }
                                }
                                .padding(20)
                            }
                            .onAppear {
                                updateColumns(width: geometry.size.width)
                            }
                            .onChange(of: geometry.size.width) { width in
                                updateColumns(width: width)
                            }
                            .onChange(of: viewModel.selectedIndex) { newIndex in
                                if newIndex < viewModel.books.count {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        proxy.scrollTo(viewModel.books[newIndex].id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if viewModel.isScanning {
                    ProgressView("폴더 스캔 중...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("MCV 책장")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        viewModel.selectFolder()
                    }) {
                        Label("폴더 변경", systemImage: "folder")
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedBookForNavigation != nil },
                set: { if !$0 { selectedBookForNavigation = nil } }
            )) {
                if let book = selectedBookForNavigation {
                    ViewerView(book: book, allBooks: viewModel.books)
                }
            }
            .onAppear {
                viewModel.installKeyMonitor()
                viewModel.openSelectedBookAction = { book in
                    if book.type == .book {
                        selectedBookForNavigation = book
                    } else if book.type == .folder {
                        viewModel.scanFolder(url: book.url)
                    } else if book.type == .upFolder {
                        viewModel.scanFolder(url: book.url)
                    }
                }
            }
            .onDisappear {
                viewModel.removeKeyMonitor()
            }
        }
    }
    
    private func updateColumns(width: CGFloat) {
        guard width > 0 else { return }
        let cols = max(1, Int((width - 20) / 180))
        if viewModel.columnsCount != cols {
            viewModel.columnsCount = cols
        }
    }
}

struct BookItemView: View {
    let book: ComicBook
    @ObservedObject var viewModel: LibraryViewModel
    let isSelected: Bool
    
    @AppStorage var bookmark: Int
    
    init(book: ComicBook, viewModel: LibraryViewModel, isSelected: Bool) {
        self.book = book
        self.viewModel = viewModel
        self.isSelected = isSelected
        self._bookmark = AppStorage(wrappedValue: 0, "bookmark_\(book.id)")
    }
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .aspectRatio(0.7, contentMode: .fit)
                .overlay(
                    Group {
                        if book.type == .upFolder {
                            Image(systemName: "arrow.turn.left.up")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        } else if book.isThumbnailLoaded {
                            if let image = viewModel.getThumbnail(for: book) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: book.type == .folder ? "folder.fill" : "doc.text")
                                    .font(.system(size: 80))
                                    .foregroundColor(book.type == .folder ? .blue.opacity(0.8) : .gray)
                            }
                        } else {
                            ProgressView()
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3.5)
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .shadow(color: isSelected ? Color.blue.opacity(0.6) : Color.black.opacity(0.3), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
                .animation(.easeOut(duration: 0.15), value: isSelected)
                .overlay(alignment: .bottomLeading) {
                    if book.type == .folder {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(6)
                            .background(Color.blue.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding([.bottom, .leading], 8)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if book.type == .book && bookmark > 0 {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(.red)
                            .font(.title)
                            .padding([.bottom, .trailing], 8)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                }
            
            Text(book.title)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected ? .blue : .primary)
                .frame(height: 40, alignment: .top)
        }
        .contextMenu {
            if book.type == .book {
                Button {
                    let parentFolder = book.url.deletingLastPathComponent()
                    UserDefaults.standard.set(book.url.lastPathComponent, forKey: "folder_thumb_\(parentFolder.path)")
                } label: {
                    Label("상위 폴더 썸네일로 지정", systemImage: "photo.badge.plus")
                }
            }
        }
    }
}
