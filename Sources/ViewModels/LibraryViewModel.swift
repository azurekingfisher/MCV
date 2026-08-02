import Foundation
import AppKit
import Combine

class LibraryViewModel: ObservableObject {
    @Published var books: [ComicBook] = []
    @Published var selectedFolderURL: URL?
    @Published var displayMode: DisplayMode = .thumbnailAndTitle
    @Published var isScanning: Bool = false
    @Published var selectedIndex: Int = 0
    @Published var columnsCount: Int = 4
    
    var openSelectedBookAction: ((ComicBook) -> Void)?
    private var keyMonitor: Any?
    
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
    
    deinit {
        removeKeyMonitor()
    }
    
    func installKeyMonitor() {
        removeKeyMonitor()
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, !self.books.isEmpty else { return event }
            
            let count = self.books.count
            let columns = max(1, self.columnsCount)
            
            switch event.keyCode {
            case 123: // ← 왼쪽 방향키
                self.selectedIndex = max(0, self.selectedIndex - 1)
                return nil
            case 124: // → 오른쪽 방향키
                self.selectedIndex = min(count - 1, self.selectedIndex + 1)
                return nil
            case 126: // ↑ 위 방향키
                self.selectedIndex = max(0, self.selectedIndex - columns)
                return nil
            case 125: // ↓ 아래 방향키
                self.selectedIndex = min(count - 1, self.selectedIndex + columns)
                return nil
            case 36, 76, 49: // 엔터 / 스페이스 키 (Main Enter / Keypad Enter / Space)
                if self.selectedIndex < count {
                    let targetBook = self.books[self.selectedIndex]
                    DispatchQueue.main.async {
                        self.openSelectedBookAction?(targetBook)
                    }
                }
                return nil
            default:
                break
            }
            return event
        }
    }
    
    func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
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
                
                // macOS Finder 자연어 정렬 (가나다/알파벳/숫자 순서대로 정렬)
                let sortedZipFiles = zipFiles.sorted { url1, url2 in
                    url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
                }
                
                let newBooks = sortedZipFiles.map { ComicBook(url: $0) }
                
                DispatchQueue.main.async {
                    self.books = newBooks
                    self.selectedIndex = 0
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
