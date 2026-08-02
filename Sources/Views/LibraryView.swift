import SwiftUI

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedBook: ComicBook?
    
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
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)], spacing: 30) {
                            ForEach(viewModel.books) { book in
                                NavigationLink(value: book) {
                                    BookItemView(book: book, viewModel: viewModel)
                                }
                                .buttonStyle(.plain) // 기본 버튼 스타일 제거
                            }
                        }
                        .padding(20)
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
            .navigationDestination(for: ComicBook.self) { book in
                ViewerView(book: book, allBooks: viewModel.books)
            }
        }
    }
}

struct BookItemView: View {
    let book: ComicBook
    @ObservedObject var viewModel: LibraryViewModel
    
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
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
            
            Text(book.title)
                .font(.callout)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .frame(height: 40, alignment: .top)
        }
        // Hover effect could be added here
    }
}
