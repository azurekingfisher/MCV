import Foundation
import AppKit
import Combine

class LibraryViewModel: ObservableObject {
    @Published var books: [ComicBook] = []
    @Published var selectedFolderURL: URL?
    @Published var displayMode: DisplayMode = .thumbnailAndTitle
    @Published var isScanning: Bool = false
    
    enum DisplayMode {
        case thumbnailAndTitle
        case thumbnailOnly
        case titleOnly
    }
    
    private let zipService: ZipArchiveServiceProtocol
    private let cacheService: ThumbnailCacheServiceProtocol
    
    init(zipService: ZipArchiveServiceProtocol = ZipArchiveService(),
         cacheService: ThumbnailCacheServiceProtocol = ThumbnailCacheService()) {
        self.zipService = zipService
        self.cacheService = cacheService
        loadLastSelectedFolder()
    }
    
    private func loadLastSelectedFolder() {
        let fileManager = FileManager.default
        
        // 1. 보안 북마크 데이터로 복원 시도
        if let bookmarkData = UserDefaults.standard.data(forKey: "lastSelectedFolderBookmark") {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale),
               fileManager.fileExists(atPath: url.path) {
                _ = url.startAccessingSecurityScopedResource()
                self.selectedFolderURL = url
                scanFolder(url: url)
                return
            }
        }
        
        // 2. 저장된 파일 경로로 복원 시도
        if let savedPath = UserDefaults.standard.string(forKey: "lastSelectedFolderURL") {
            let url = URL(fileURLWithPath: savedPath)
            if fileManager.fileExists(atPath: url.path) {
                self.selectedFolderURL = url
                scanFolder(url: url)
            }
        }
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                self.selectedFolderURL = url
                
                // UserDefaults 및 북마크 저장
                UserDefaults.standard.set(url.path, forKey: "lastSelectedFolderURL")
                if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    UserDefaults.standard.set(bookmarkData, forKey: "lastSelectedFolderBookmark")
                }
                
                scanFolder(url: url)
            }
        }
    }
    
    func scanFolder(url: URL) {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
                
                let zipFiles = contents.filter { $0.pathExtension.lowercased() == "zip" }
                
                let newBooks = zipFiles.map { ComicBook(url: $0) }
                
                DispatchQueue.main.async {
                    self.books = newBooks
                    self.isScanning = false
                    // 썸네일 로딩 시작
                    self.loadThumbnails()
                }
            } catch {
                print("Error scanning folder: \(error)")
                DispatchQueue.main.async {
                    self.isScanning = false
                }
            }
        }
    }
    
    private func loadThumbnails() {
        for (index, book) in books.enumerated() {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                
                if self.cacheService.getThumbnail(for: book.id) != nil {
                    DispatchQueue.main.async {
                        self.books[index].isThumbnailLoaded = true
                    }
                } else {
                    // Extract first image to generate thumbnail
                    do {
                        let entries = try self.zipService.getPageEntries(from: book.url)
                        if let firstEntry = entries.first {
                            let imageData = try self.zipService.extractImageData(from: book.url, entryName: firstEntry)
                            if let image = NSImage(data: imageData) {
                                self.cacheService.saveThumbnail(image: image, for: book.id)
                                DispatchQueue.main.async {
                                    self.books[index].isThumbnailLoaded = true
                                }
                            }
                        }
                    } catch {
                        print("Failed to load thumbnail for \(book.title)")
                    }
                }
            }
        }
    }
    
    func getThumbnail(for book: ComicBook) -> NSImage? {
        return cacheService.getThumbnail(for: book.id)
    }
}
