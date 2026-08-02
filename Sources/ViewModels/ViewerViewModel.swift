import Foundation
import AppKit
import Combine
import SwiftUI

class ViewerViewModel: ObservableObject {
    // 메뉴 커맨드에서 접근할 수 있도록 현재 활성 뷰어를 추적
    static var current: ViewerViewModel?
    @Published var book: ComicBook
    @Published var currentIndex: Int = 0
    @Published var currentPages: [ComicPage] = []
    
    // View settings
    @Published var isTwoPageMode: Bool = false { didSet { updateCurrentPages() } }
    @Published var isRightToLeft: Bool = true { didSet { updateCurrentPages() } } // 만화책은 보통 우측에서 좌측으로 읽음
    @Published var isSpreadInverted: Bool = false { didSet { updateCurrentPages() } }
    @Published var isFitToWidth: Bool = false
    
    // Zoom & Pan state
    @Published var scale: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero
    
    var isZoomed: Bool {
        abs(scale - 1.0) > 0.05
    }
    
    func zoomIn() {
        withAnimation(.easeOut(duration: 0.15)) {
            scale = min(4.0, scale + 0.25)
        }
    }
    
    func zoomOut() {
        withAnimation(.easeOut(duration: 0.15)) {
            let newScale = scale - 0.25
            if newScale <= 1.0 {
                resetZoom()
            } else {
                scale = newScale
            }
        }
    }
    
    func resetZoom() {
        withAnimation(.easeOut(duration: 0.15)) {
            scale = 1.0
            panOffset = .zero
        }
    }
    
    func pan(dx: CGFloat, dy: CGFloat) {
        withAnimation(.easeOut(duration: 0.1)) {
            panOffset.width += dx
            panOffset.height += dy
        }
    }
    
    // Navigation
    @Published var volumeOverlayMessage: String?
    @Published var totalPages: Int = 0
    
    // UI state
    @Published var isControlsVisible: Bool = false
    
    private let zipService: ZipArchiveServiceProtocol
    private var entries: [String] = []
    private var pageCache: [Int: ComicPage] = [:]
    private let allBooks: [ComicBook]
    
    // Esc 키 및 키보드 단축키 모니터
    var dismissAction: (() -> Void)?
    var scrollAction: ((CGFloat) -> Void)?
    var scrollToTopAction: (() -> Void)?
    weak var window: NSWindow?
    private var keyMonitor: Any?
    
    init(book: ComicBook, allBooks: [ComicBook] = [], zipService: ZipArchiveServiceProtocol = ZipArchiveService()) {
        self.book = book
        self.allBooks = allBooks
        self.zipService = zipService
        loadEntries()
    }
    
    deinit {
        removeKeyMonitor()
    }
    
    func installKeyMonitor(dismissAction: @escaping () -> Void) {
        removeKeyMonitor()
        self.dismissAction = dismissAction
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // 1. 키코드 기반 처리 (물리적 키 위치: 한글/영문 입력기 종류에 상관없이 100% 동일하게 동작)
            switch event.keyCode {
            case 123: // ← 왼쪽 방향키
                if self.isZoomed {
                    self.pan(dx: 100, dy: 0)
                    return nil
                } else {
                    self.turnPage(forward: self.isRightToLeft)
                    return nil
                }
            case 124: // → 오른쪽 방향키
                if self.isZoomed {
                    self.pan(dx: -100, dy: 0)
                    return nil
                } else {
                    self.turnPage(forward: !self.isRightToLeft)
                    return nil
                }
            case 125: // ↓ 아래 방향키
                if self.isZoomed {
                    self.pan(dx: 0, dy: -100)
                    return nil
                } else if self.isFitToWidth {
                    DispatchQueue.main.async {
                        self.scrollAction?(180)
                    }
                    return nil
                }
            case 126: // ↑ 위 방향키
                if self.isZoomed {
                    self.pan(dx: 0, dy: 100)
                    return nil
                } else if self.isFitToWidth {
                    DispatchQueue.main.async {
                        self.scrollAction?(-180)
                    }
                    return nil
                }
            case 27: // - 키 (알파벳 상단 키패드 - 축소)
                self.zoomOut()
                return nil
            case 24: // = / + 키 (알파벳 상단 키패드 - 확대)
                self.zoomIn()
                return nil
            case 29: // 0 키 (알파벳 상단 키패드 - 배율 초기화)
                self.resetZoom()
                return nil
            case 53: // Esc 키 (전체화면 모드 여부와 관계없이 책장으로 돌아가기)
                let targetWindow = self.window ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isKeyWindow })
                if let targetWindow = targetWindow, targetWindow.styleMask.contains(.fullScreen) {
                    targetWindow.toggleFullScreen(nil)
                }
                self.dismissAction?()
                return nil
            case 3: // F 키 (영문 F / 한글 ㄹ) - 전체화면
                let targetWindow = self.window ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isKeyWindow })
                if let targetWindow = targetWindow {
                    targetWindow.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
                    targetWindow.styleMask.insert([.titled, .resizable, .closable, .miniaturizable])
                    DispatchQueue.main.async {
                        targetWindow.toggleFullScreen(nil)
                    }
                }
                return nil
            case 9: // V 키 (영문 V / 한글 ㅍ) - 세로 맞춤
                self.isFitToWidth = false
                return nil
            case 4: // H 키 (영문 H / 한글 ㅗ) - 가로 맞춤
                self.isFitToWidth = true
                return nil
            case 33: // [ 키 (영문 [ / 한글 ㅐ) - 이전 파일
                self.changeBook(forward: false)
                return nil
            case 30: // ] 키 (영문 ] / 한글 ㅔ) - 다음 파일
                self.changeBook(forward: true)
                return nil
            default:
                break
            }
            
            // 2. 문자 기반 보완 처리 (한글 입력기 상태 지원 및 기호 지원)
            if let chars = event.charactersIgnoringModifiers?.lowercased() {
                switch chars {
                case "-", "_":
                    self.zoomOut()
                    return nil
                case "=", "+":
                    self.zoomIn()
                    return nil
                case "0":
                    self.resetZoom()
                    return nil
                case "f", "ㄹ":
                    let targetWindow = self.window ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isKeyWindow })
                    if let targetWindow = targetWindow {
                        targetWindow.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
                        targetWindow.styleMask.insert([.titled, .resizable, .closable, .miniaturizable])
                        DispatchQueue.main.async {
                            targetWindow.toggleFullScreen(nil)
                        }
                    }
                    return nil
                case "v", "ㅍ":
                    self.isFitToWidth = false
                    return nil
                case "h", "ㅗ", "ㅎ":
                    self.isFitToWidth = true
                    return nil
                case "[", "ㅐ":
                    self.changeBook(forward: false)
                    return nil
                case "]", "ㅔ":
                    self.changeBook(forward: true)
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
    
    private func loadEntries() {
        do {
            entries = try zipService.getPageEntries(from: book.url)
            book.totalPages = entries.count
            totalPages = entries.count
            
            if totalPages > 0 {
                updateCurrentPages()
            }
        } catch {
            print("Failed to load entries: \(error)")
        }
    }
    
    func turnPage(forward: Bool) {
        let step = isTwoPageMode ? 2 : 1
        
        // 방향 계산 (isRightToLeft가 참이면 forward가 왼쪽으로 가는 것(페이지 증가))
        var nextIndex = currentIndex
        
        if forward {
            nextIndex += step
        } else {
            nextIndex -= step
        }
        
        if nextIndex >= totalPages {
            showVolumeOverlay(message: "마지막 장입니다.")
            return
        }
        
        if nextIndex < 0 {
            showVolumeOverlay(message: "첫 장입니다.")
            return
        }
        
        currentIndex = nextIndex
        updateCurrentPages()
    }
    
    private func showVolumeOverlay(message: String) {
        volumeOverlayMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.volumeOverlayMessage == message {
                self.volumeOverlayMessage = nil
            }
        }
    }
    
    func updateCurrentPages() {
        guard currentIndex < totalPages else { return }
        
        var newPages: [ComicPage] = []
        
        // 첫 번째 페이지 로드
        let page1 = getPage(at: currentIndex)
        newPages.append(page1)
        
        if isTwoPageMode {
            // 가로형 스프레드 감지 로직
            if let img = page1.image, img.size.width > img.size.height {
                // 가로가 세로보다 길면 한 장만 꽉 차게 보여줌 (스프레드 예외 처리)
            } else if currentIndex + 1 < totalPages {
                // 다음 페이지 로드
                let page2 = getPage(at: currentIndex + 1)
                
                // 두 번째 페이지도 가로형이면 따로 보여줘야 하지만, 단순화를 위해 첫페이지만 체크
                if let img2 = page2.image, img2.size.width > img2.size.height {
                    // 예외
                } else {
                    newPages.append(page2)
                }
            }
        }
        
        // 표시 순서 결정
        if newPages.count == 2 {
            if (isRightToLeft && !isSpreadInverted) || (!isRightToLeft && isSpreadInverted) {
                newPages.swapAt(0, 1) // 오른쪽에서 왼쪽으로 읽으면 다음 페이지가 왼쪽에 렌더링되어야 함
            }
        }
        
        self.currentPages = newPages
        
        // 페이지 변경 시 가로 꽉 참 스크롤을 항상 맨 위로 리셋
        scrollToTop()
        
        // 메모리 관리를 위해 앞뒤 2페이지만 캐싱하고 나머지는 삭제
        manageCache()
    }
    
    func scrollToTop() {
        DispatchQueue.main.async {
            self.scrollToTopAction?()
        }
    }
    
    private func getPage(at index: Int) -> ComicPage {
        if let cached = pageCache[index] {
            return cached
        }
        
        let entryName = entries[index]
        do {
            let data = try zipService.extractImageData(from: book.url, entryName: entryName)
            let page = ComicPage(index: index, entryName: entryName, imageData: data)
            pageCache[index] = page
            return page
        } catch {
            print("Error extracting page \(index): \(error)")
            return ComicPage(index: index, entryName: entryName, imageData: nil)
        }
    }
    
    private func manageCache() {
        // 현재 인덱스 기준 앞뒤 2페이지(양면일 경우 더 넓게) 유지
        let buffer = isTwoPageMode ? 4 : 2
        let keepRange = (currentIndex - buffer)...(currentIndex + buffer + (isTwoPageMode ? 1 : 0))
        
        for key in pageCache.keys {
            if !keepRange.contains(key) {
                pageCache.removeValue(forKey: key)
            }
        }
    }
    
    func seek(to index: Int) {
        guard index >= 0 && index < totalPages else { return }
        // 양면 보기일 경우 짝수/홀수 인덱스 교정 필요 (기본적으로 0부터 시작한다고 가정할때 짝수로 맞춤)
        var newIndex = index
        if isTwoPageMode && newIndex % 2 != 0 {
            newIndex -= 1
        }
        currentIndex = newIndex
        updateCurrentPages()
    }
    
    func changeBook(forward: Bool) {
        guard !allBooks.isEmpty else { return }
        guard let bookIndex = allBooks.firstIndex(where: { $0.id == book.id }) else { return }
        
        let nextIndex = forward ? bookIndex + 1 : bookIndex - 1
        
        if nextIndex >= 0 && nextIndex < allBooks.count {
            self.pageCache.removeAll()
            self.currentPages = []
            
            self.book = allBooks[nextIndex]
            self.currentIndex = 0
            self.loadEntries()
            
            showVolumeOverlay(message: self.book.title)
        } else {
            showVolumeOverlay(message: forward ? "마지막 권입니다." : "첫 권입니다.")
        }
    }
}
