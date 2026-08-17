import Foundation
import AppKit
import Combine

class LibraryViewModel: ObservableObject {
    static var current: LibraryViewModel?
    
    @Published var books: [ComicBook] = []
    @Published var rootFolderURL: URL?
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
    
    enum SortOption: String, CaseIterable, Identifiable {
        case name = "자연어순"
        case dateAdded = "최신순"
        var id: String { rawValue }
    }
    
    enum SortDirection: String, CaseIterable, Identifiable {
        case ascending = "오름차순"
        case descending = "내림차순"
        var id: String { rawValue }
    }
    
    @Published var sortOption: SortOption = SortOption(rawValue: UserDefaults.standard.string(forKey: "librarySortOption") ?? "자연어순") ?? .name {
        didSet {
            UserDefaults.standard.set(sortOption.rawValue, forKey: "librarySortOption")
            if let url = selectedFolderURL { scanFolder(url: url) }
        }
    }
    
    @Published var sortDirection: SortDirection = SortDirection(rawValue: UserDefaults.standard.string(forKey: "librarySortDirection") ?? "오름차순") ?? .ascending {
        didSet {
            UserDefaults.standard.set(sortDirection.rawValue, forKey: "librarySortDirection")
            if let url = selectedFolderURL { scanFolder(url: url) }
        }
    }
    
    var selectedBookId: String? {
        guard selectedIndex >= 0 && selectedIndex < books.count else { return nil }
        return books[selectedIndex].id
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
            guard let self = self else { return event }
            
            // 뷰어 모드가 활성화되어 있으면 책장 키 모니터는 작동하지 않고 통과시킴
            if ViewerViewModel.current != nil {
                return event
            }
            
            // Cmd + O: 폴더 열기 (책 목록이 비어있어도 책장 모드라면 즉시 동작)
            if event.modifierFlags.contains(.command) {
                if event.keyCode == 31 || event.charactersIgnoringModifiers?.lowercased() == "o" || event.charactersIgnoringModifiers?.lowercased() == "ㅐ" {
                    DispatchQueue.main.async {
                        self.selectFolder()
                    }
                    return nil
                }
                return event
            }
            
            guard !self.books.isEmpty else { return event }
            
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
            case 53: // Esc 키
                if self.selectedFolderURL != self.rootFolderURL {
                    if let current = self.selectedFolderURL, let root = self.rootFolderURL {
                        if current.path != root.path {
                            let parentURL = current.deletingLastPathComponent()
                            DispatchQueue.main.async {
                                self.scanFolder(url: parentURL)
                            }
                        }
                    }
                }
                // esc로 전체화면이 해제되는 macOS 기본 동작을 막기 위해 무조건 이벤트를 삼킴 (nil 반환)
                return nil
            case 3: // F 키 (영문 F / 한글 ㄹ) - 전체화면
                let targetWindow = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isKeyWindow })
                if let targetWindow = targetWindow {
                    targetWindow.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
                    targetWindow.styleMask.insert([.titled, .resizable, .closable, .miniaturizable])
                    DispatchQueue.main.async {
                        targetWindow.toggleFullScreen(nil)
                    }
                }
                return nil
            default:
                break
            }
            
            // 2. 문자 기반 보완 처리 (한글 입력기 상태 지원 및 기호 지원)
            if let chars = event.charactersIgnoringModifiers?.lowercased() {
                switch chars {
                case "f", "ㄹ":
                    let targetWindow = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isKeyWindow })
                    if let targetWindow = targetWindow {
                        targetWindow.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
                        targetWindow.styleMask.insert([.titled, .resizable, .closable, .miniaturizable])
                        DispatchQueue.main.async {
                            targetWindow.toggleFullScreen(nil)
                        }
                    }
                    return nil
                default:
                    break
                }
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
                self.rootFolderURL = url
                self.selectedFolderURL = url
                scanFolder(url: url)
                return
            }
        }
        
        // 2. 저장된 파일 경로로 복원 시도
        if let savedPath = UserDefaults.standard.string(forKey: "lastSelectedFolderURL") {
            let url = URL(fileURLWithPath: savedPath)
            if fileManager.fileExists(atPath: url.path) {
                self.rootFolderURL = url
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
                self.rootFolderURL = url
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
        let previousFolderURL = self.selectedFolderURL
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey], options: .skipsHiddenFiles)
                
                var folders: [ComicBook] = []
                var zipFiles: [ComicBook] = []
                
                for itemUrl in contents {
                    let isDir = (try? itemUrl.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir {
                        folders.append(ComicBook(url: itemUrl, type: .folder))
                    } else if itemUrl.pathExtension.lowercased() == "zip" {
                        zipFiles.append(ComicBook(url: itemUrl, type: .book))
                    }
                }
                
                let sortClosure: (ComicBook, ComicBook) -> Bool = { [weak self] a, b in
                    guard let self = self else { return false }
                    let isAscending = self.sortDirection == .ascending
                    
                    let compareResult: ComparisonResult
                    if self.sortOption == .name {
                        compareResult = a.title.localizedStandardCompare(b.title)
                    } else {
                        compareResult = a.creationDate == b.creationDate ? .orderedSame : (a.creationDate < b.creationDate ? .orderedAscending : .orderedDescending)
                    }
                    
                    if compareResult == .orderedSame {
                        return false
                    }
                    
                    return isAscending ? (compareResult == .orderedAscending) : (compareResult == .orderedDescending)
                }
                
                folders.sort(by: sortClosure)
                zipFiles.sort(by: sortClosure)
                
                var newBooks: [ComicBook] = []
                
                // 상위 폴더로 가는 아이콘 (현재 폴더가 최상위 폴더가 아닐 경우)
                if let root = self.rootFolderURL, url != root {
                    let upUrl = url.deletingLastPathComponent()
                    newBooks.append(ComicBook(url: upUrl, type: .upFolder))
                }
                
                newBooks.append(contentsOf: folders)
                newBooks.append(contentsOf: zipFiles)
                
                DispatchQueue.main.async {
                    self.selectedFolderURL = url
                    self.books = newBooks
                    
                    if let prev = previousFolderURL, prev.deletingLastPathComponent().path == url.path {
                        if let targetIndex = newBooks.firstIndex(where: { $0.url.path == prev.path }) {
                            self.selectedIndex = targetIndex
                        } else {
                            self.selectedIndex = 0
                        }
                    } else {
                        self.selectedIndex = 0
                    }
                    
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
    private func getRepresentativeZipURL(forFolder folderURL: URL) -> URL? {
        // 1. UserDefaults에서 커스텀 썸네일 확인
        if let customFilename = UserDefaults.standard.string(forKey: "folder_thumb_\(folderURL.path)") {
            let customURL = folderURL.appendingPathComponent(customFilename)
            if FileManager.default.fileExists(atPath: customURL.path) {
                return customURL
            }
        }
        
        // 2. 기본값: 폴더 내 첫 번째 zip 파일
        guard let contents = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return nil }
        let zipFiles = contents.filter { $0.pathExtension.lowercased() == "zip" }
        return zipFiles.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }.first
    }
    
    private func loadThumbnails() {
        for (index, book) in books.enumerated() {
            if book.type == .upFolder { continue }
            
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self = self else { return }
                
                let targetURL = book.type == .folder ? self.getRepresentativeZipURL(forFolder: book.url) : book.url
                guard let zipURL = targetURL else {
                    DispatchQueue.main.async { self.books[index].isThumbnailLoaded = true }
                    return
                }
                
                let zipId = ComicBook(url: zipURL, type: .book).id
                
                if self.cacheService.getThumbnail(for: zipId) != nil {
                    DispatchQueue.main.async {
                        self.books[index].isThumbnailLoaded = true
                    }
                } else {
                    // Extract first image to generate thumbnail
                    do {
                        let entries = try self.zipService.getPageEntries(from: zipURL)
                        if let firstEntry = entries.first {
                            let imageData = try self.zipService.extractImageData(from: zipURL, entryName: firstEntry)
                            if let image = NSImage(data: imageData) {
                                self.cacheService.saveThumbnail(image: image, for: zipId)
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
        if book.type == .folder {
            guard let zipURL = getRepresentativeZipURL(forFolder: book.url) else { return nil }
            return cacheService.getThumbnail(for: ComicBook(url: zipURL, type: .book).id)
        }
        return cacheService.getThumbnail(for: book.id)
    }
}
