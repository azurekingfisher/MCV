import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedBookForNavigation: ComicBook?
    
    // 무채색 배경
    private let backgroundColor = Color(NSColor.windowBackgroundColor)
    
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
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)], spacing: 30) {
                                    ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
                                        BookItemView(book: book, viewModel: viewModel, isSelected: index == viewModel.selectedIndex)
                                            .id(book.id)
                                            .onTapGesture {
                                                viewModel.selectedIndex = index
                                                selectedBookForNavigation = book
                                            }
                                    }
                                }
                                .padding(20)
                            }
                            .onChange(of: geometry.size.width) { width in
                                let cols = max(1, Int((width - 20) / 200))
                                viewModel.columnsCount = cols
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
                    selectedBookForNavigation = book
                }
            }
            .onDisappear {
                viewModel.removeKeyMonitor()
            }
        }
    }
}

struct BookItemView: View {
    let book: ComicBook
    @ObservedObject var viewModel: LibraryViewModel
    let isSelected: Bool
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .aspectRatio(0.7, contentMode: .fit)
                .overlay(
                    Group {
                        if book.isThumbnailLoaded, let image = viewModel.getThumbnail(for: book) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
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
            
            Text(book.title)
                .font(.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected ? .blue : .primary)
                .frame(height: 40, alignment: .top)
        }
    }
}
