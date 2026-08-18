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
                                    ForEach(viewModel.books) { book in
                                        BookItemView(book: book, viewModel: viewModel, isSelected: viewModel.selectedBookId == book.id)
                                            .id(book.id)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if let idx = viewModel.books.firstIndex(where: { $0.id == book.id }) {
                                                    viewModel.selectedIndex = idx
                                                }
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
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("정렬 기준", selection: $viewModel.sortOption) {
                        ForEach(LibraryViewModel.SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    
                    Button(action: {
                        viewModel.sortDirection = viewModel.sortDirection == .ascending ? .descending : .ascending
                    }) {
                        Image(systemName: viewModel.sortDirection == .ascending ? "arrow.up" : "arrow.down")
                    }
                    .help("오름차순/내림차순 전환")
                    
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
                LibraryViewModel.current = viewModel
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
                LibraryViewModel.current = nil
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

// MARK: - 썸네일 표지 영역 크롭/표시 모드
enum ThumbnailCropMode: String, CaseIterable, Identifiable {
    case center = "center"
    case left = "left"
    case right = "right"
    case fit = "fit"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .center: return "현재 방식 (기본)"
        case .left: return "책의 왼쪽만 보여주기"
        case .right: return "책의 오른쪽만 보여주기"
        case .fit: return "가로로 꽉 차게 보여주기"
        }
    }
    
    var next: ThumbnailCropMode {
        switch self {
        case .center: return .left
        case .left: return .right
        case .right: return .fit
        case .fit: return .center
        }
    }
}

struct BookItemView: View {
    let book: ComicBook
    @ObservedObject var viewModel: LibraryViewModel
    let isSelected: Bool
    
    @AppStorage var bookmark: Int
    @AppStorage var cropModeRaw: String
    
    private var cropMode: ThumbnailCropMode {
        get { ThumbnailCropMode(rawValue: cropModeRaw) ?? .center }
        nonmutating set { cropModeRaw = newValue.rawValue }
    }
    
    init(book: ComicBook, viewModel: LibraryViewModel, isSelected: Bool) {
        self.book = book
        self.viewModel = viewModel
        self.isSelected = isSelected
        self._bookmark = AppStorage(wrappedValue: 0, "bookmark_\(book.id)")
        self._cropModeRaw = AppStorage(wrappedValue: ThumbnailCropMode.center.rawValue, "thumb_crop_\(book.id)")
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
                                thumbnailImageView(image: image)
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
            if book.type == .book || book.type == .folder {
                Button {
                    cropMode = cropMode.next
                } label: {
                    Label("표지 영역: \(cropMode.title)", systemImage: "rectangle.split.2x1")
                }
                
                Menu("표지 영역 선택") {
                    ForEach(ThumbnailCropMode.allCases) { mode in
                        Button {
                            cropMode = mode
                        } label: {
                            HStack {
                                Text(mode.title)
                                if cropMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Divider()
            }
            
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
    
    @ViewBuilder
    private func thumbnailImageView(image: NSImage) -> some View {
        GeometryReader { geo in
            switch cropMode {
            case .center:
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            case .left:
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            case .right:
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .trailing)
            case .fit:
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
        }
    }
}
