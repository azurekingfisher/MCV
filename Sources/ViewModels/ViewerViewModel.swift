import Foundation
import AppKit
import Combine
import SwiftUI

class ViewerViewModel: ObservableObject {
    // 메뉴 커맨드에서 접근할 수 있도록 현재 활성 뷰어를 추적
    static var current: ViewerViewModel?
    @Published var book: ComicBook
    @Published var currentIndex: Int = 0 {
        didSet {
            UserDefaults.standard.set(currentIndex, forKey: "bookmark_\(book.id)")
        }
    }
    @Published var currentPages: [ComicPage] = []
    
    // View settings
    @Published var isTwoPageMode: Bool = false { didSet { updateCurrentPages() } }
    @Published var isRightToLeft: Bool = true { didSet { updateCurrentPages() } } // 만화책은 보통 우측에서 좌측으로 읽음
    @Published var isSpreadInverted: Bool = false { didSet { updateCurrentPages() } }
    @Published var isFitToWidth: Bool = false
    @Published var sharpenLevel: SharpenLevel = SharpenLevel(rawValue: UserDefaults.standard.string(forKey: "sharpenLevel") ?? "끄기") ?? .off {
        didSet {
            UserDefaults.standard.set(sharpenLevel.rawValue, forKey: "sharpenLevel")
        }
    }
    
    @Published var autoContrast: Bool = false {
        didSet {
            UserDefaults.standard.set(autoContrast, forKey: "autoContrast_\(book.id)")
        }
    }
    
    @Published var prevPageZoomPosition: ZoomPrevPagePosition = ZoomPrevPagePosition(rawValue: UserDefaults.standard.string(forKey: "prevPageZoomPosition") ?? "bottom") ?? .bottom {
        didSet {
            UserDefaults.standard.set(prevPageZoomPosition.rawValue, forKey: "prevPageZoomPosition")
        }
    }
    
    // Zoom & Pan state
    @Published var scale: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero
    @Published var viewportSize: CGSize = .zero
    
    var isZoomed: Bool {
        abs(scale - 1.0) > 0.05
    }
    
    /// 확대 상태에서 이미지 폭이 화면 폭보다 커서 좌우 패닝이 가능한지 여부
    var canPanHorizontally: Bool {
        guard isZoomed else { return false }
        return maxPanOffset().width > 1.0
    }
    
    func getCombinedAspectRatio() -> CGFloat? {
        guard !currentPages.isEmpty else { return nil }
        var totalRatio: CGFloat = 0
        for page in currentPages {
            if let image = page.image, image.size.height > 0 {
                totalRatio += image.size.width / image.size.height
            }
        }
        return totalRatio > 0 ? totalRatio : nil
    }
    
    func maxPanOffset(for scaleValue: CGFloat? = nil) -> CGSize {
        let currentScale = scaleValue ?? self.scale
        let vSize = (viewportSize.width > 0 && viewportSize.height > 0) ? viewportSize : (window?.contentView?.frame.size ?? .zero)
        
        guard currentScale > 1.0, vSize.width > 0, vSize.height > 0 else {
            return .zero
        }
        
        guard let ratio = getCombinedAspectRatio(), ratio > 0 else {
            return .zero
        }
        
        let viewportW = vSize.width
        let viewportH = vSize.height
        let viewportRatio = viewportW / viewportH
        
        let baseW: CGFloat
        let baseH: CGFloat
        
        if ratio > viewportRatio {
            // 이미지의 가로 비율이 뷰포트보다 더 넓은 경우 (가로에 맞춰짐)
            baseW = viewportW
            baseH = viewportW / ratio
        } else {
            // 이미지의 세로 비율이 뷰포트보다 더 긴 경우 (세로에 맞춰짐)
            baseH = viewportH
            baseW = viewportH * ratio
        }
        
        let renderedW = baseW * currentScale
        let renderedH = baseH * currentScale
        
        let maxX = max(0, (renderedW - viewportW) / 2)
        let maxY = max(0, (renderedH - viewportH) / 2)
        
        return CGSize(width: maxX, height: maxY)
    }
    
    func clampPanOffset(_ offset: CGSize, for scaleValue: CGFloat? = nil) -> CGSize {
        let maxOffset = maxPanOffset(for: scaleValue)
        let clampedX = maxOffset.width > 0 ? min(maxOffset.width, max(-maxOffset.width, offset.width)) : 0
        let clampedY = maxOffset.height > 0 ? min(maxOffset.height, max(-maxOffset.height, offset.height)) : 0
        return CGSize(width: clampedX, height: clampedY)
    }
    
    func zoomIn() {
        withAnimation(.easeOut(duration: 0.15)) {
            let newScale = min(4.0, scale + 0.25)
            scale = newScale
            panOffset = clampPanOffset(panOffset, for: newScale)
        }
    }
    
    func zoomOut() {
        withAnimation(.easeOut(duration: 0.15)) {
            let newScale = scale - 0.25
            if newScale <= 1.0 {
                resetZoom()
            } else {
                scale = newScale
                panOffset = clampPanOffset(panOffset, for: newScale)
            }
        }
    }
    
    func resetZoom() {
        withAnimation(.easeOut(duration: 0.15)) {
            scale = 1.0
            panOffset = .zero
        }
    }
    
    func toggleSmartZoom() {
        if self.isZoomed {
            self.resetZoom()
        } else {
            let ratio = UserDefaults.standard.double(forKey: "smartZoomRatio")
            let targetRatio = ratio > 0 ? ratio : 2.0
            let maxOffset = maxPanOffset(for: targetRatio)
            withAnimation(.easeOut(duration: 0.2)) {
                self.scale = targetRatio
                self.panOffset = CGSize(width: 0, height: maxOffset.height)
            }
            if isFitToWidth {
                scrollToTop()
            }
        }
    }
    
    func pan(dx: CGFloat, dy: CGFloat, animated: Bool = false) {
        let newOffset = CGSize(width: panOffset.width + dx, height: panOffset.height + dy)
        let clamped = clampPanOffset(newOffset)
        
        if animated {
            withAnimation(.easeOut(duration: 0.1)) {
                panOffset = clamped
            }
        } else {
            panOffset = clamped
        }
    }
    
    // Navigation
    @Published var volumeOverlayMessage: String?
    @Published var totalPages: Int = 0
    
    @Published var isControlsVisible: Bool = false
    
    // Swipe interaction state
    @Published var prevPages: [ComicPage] = []
    @Published var nextPages: [ComicPage] = []
    @Published var swipeOffset: CGFloat = 0
    private var hasTurnedPageInCurrentSwipe: Bool = false
    
    private let zipService: ZipArchiveServiceProtocol
    private var entries: [String] = []
    private var pageCache: [Int: ComicPage] = [:]
    private let allBooks: [ComicBook]
    
    // Esc 키 및 키보드 단축키 모니터
    var dismissAction: (() -> Void)?
    var scrollAction: ((CGFloat) -> Void)?
    var scrollContinuousAction: ((CGFloat) -> Void)?
    var scrollToTopAction: (() -> Void)?
    var scrollToBottomAction: (() -> Void)?
    weak var window: NSWindow?
    private var keyMonitor: Any?
    private var scrollAccumulatorX: CGFloat = 0
    private var lastScrollTime: Date = Date()
    
    // 방향키 누르고 있을 때 지연(딜레이) 없는 60fps 즉시 연속 이동 지원
    private var heldMovementKeys = Set<UInt16>()
    private var continuousMovementTimer: Timer?
    
    init(book: ComicBook, allBooks: [ComicBook] = [], zipService: ZipArchiveServiceProtocol = ZipArchiveService()) {
        self.book = book
        self.allBooks = allBooks
        self.zipService = zipService
        self.currentIndex = UserDefaults.standard.integer(forKey: "bookmark_\(book.id)")
        self.autoContrast = UserDefaults.standard.bool(forKey: "autoContrast_\(book.id)")
        loadEntries()
    }
    
    deinit {
        removeKeyMonitor()
    }
    
    private func startContinuousMovementTimer() {
        guard continuousMovementTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tickContinuousMovement()
        }
        RunLoop.main.add(timer, forMode: .common)
        continuousMovementTimer = timer
    }
    
    private func stopContinuousMovementTimer() {
        continuousMovementTimer?.invalidate()
        continuousMovementTimer = nil
    }
    
    private func tickContinuousMovement() {
        guard !heldMovementKeys.isEmpty else {
            stopContinuousMovementTimer()
            return
        }
        
        let moveSpeed: CGFloat = 30.0 // 60fps 기준 프레임당 이동 픽셀 (약 1800px/sec - 빠른 연속 이동)
        
        if isZoomed {
            var dx: CGFloat = 0
            var dy: CGFloat = 0
            
            if heldMovementKeys.contains(123) && canPanHorizontally { // Left
                dx += moveSpeed
            }
            if heldMovementKeys.contains(124) && canPanHorizontally { // Right
                dx -= moveSpeed
            }
            if heldMovementKeys.contains(125) { // Down
                dy -= moveSpeed
            }
            if heldMovementKeys.contains(126) { // Up
                dy += moveSpeed
            }
            
            if dx != 0 || dy != 0 {
                pan(dx: dx, dy: dy, animated: false)
            }
        } else if isFitToWidth {
            var deltaY: CGFloat = 0
            if heldMovementKeys.contains(125) { // Down
                deltaY += moveSpeed
            }
            if heldMovementKeys.contains(126) { // Up
                deltaY -= moveSpeed
            }
            if deltaY != 0 {
                scrollContinuousAction?(deltaY)
            }
        } else {
            stopContinuousMovementTimer()
            heldMovementKeys.removeAll()
        }
    }
    
    func installKeyMonitor(dismissAction: @escaping () -> Void) {
        removeKeyMonitor()
        self.dismissAction = dismissAction
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .scrollWheel, .smartMagnify]) { [weak self] event in
            guard let self = self else { return event }
            
            // --- 키를 뗐을 때 (keyUp) ---
            if event.type == .keyUp {
                if self.heldMovementKeys.contains(event.keyCode) {
                    self.heldMovementKeys.remove(event.keyCode)
                    if self.heldMovementKeys.isEmpty {
                        self.stopContinuousMovementTimer()
                    }
                    return nil
                }
                return event
            }
            
            // --- 스마트 줌 (두 손가락 더블 탭) ---
            if event.type == .smartMagnify {
                self.toggleSmartZoom()
                return nil
            }
            
            // --- 트랙패드 / 마우스 스크롤 이벤트 처리 ---
            if event.type == .scrollWheel {
                if self.isZoomed {
                    // 확대 상태: 패닝 (이동 방향은 macOS 자연스러운 스크롤 기준에 따라 기본적으로 맞음)
                    self.pan(dx: event.scrollingDeltaX * 2, dy: event.scrollingDeltaY * 2)
                    return nil
                } else {
                    // 기본 상태: 페이지 스와이프 (가로 이동 중심)
                    if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
                        let now = Date()
                        // 이벤트 간격이 0.3초 이상이면 새로운 제스처로 간주
                        if now.timeIntervalSince(self.lastScrollTime) > 0.3 {
                            self.hasTurnedPageInCurrentSwipe = false
                            if self.swipeOffset == 0 {
                                self.scrollAccumulatorX = 0
                            }
                        }
                        self.lastScrollTime = now
                        
                        if event.phase == .began || event.phase == .mayBegin {
                            self.hasTurnedPageInCurrentSwipe = false
                            self.scrollAccumulatorX = 0
                            self.swipeOffset = 0
                        }
                        
                        // 이미 페이지를 넘겼다면 추가로 넘기지 않고 무시
                        if !self.hasTurnedPageInCurrentSwipe {
                            self.scrollAccumulatorX += event.scrollingDeltaX
                            
                            // 뷰어 너비를 기준으로 스와이프 오프셋 계산
                            if let w = self.window?.contentView?.frame.width, w > 0 {
                                // 화면 너비의 일부를 제스처로 이동 (속도감 조정)
                                self.swipeOffset = self.scrollAccumulatorX
                                
                                // 임계치 (화면 너비의 15% 또는 최소 100px)
                                let threshold = max(100, w * 0.15)
                                
                                if abs(self.scrollAccumulatorX) > threshold {
                                    self.hasTurnedPageInCurrentSwipe = true
                                    let isSwipingLeft = self.scrollAccumulatorX < 0
                                    let forward = self.isRightToLeft ? !isSwipingLeft : isSwipingLeft
                                    
                                    // 애니메이션으로 남은 거리를 끝까지 이동시킨 후 페이지 넘김
                                    let targetOffset = isSwipingLeft ? -w : w
                                    
                                    // 주의: withAnimation 내부에서 swipeOffset을 변경하고,
                                    // 애니메이션 완료 후(대략 0.2초) 실제 페이지 턴 수행
                                    DispatchQueue.main.async {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            self.swipeOffset = targetOffset
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            self.turnPage(forward: forward)
                                            self.swipeOffset = 0
                                            self.scrollAccumulatorX = 0
                                        }
                                    }
                                }
                            }
                        }
                        
                        if event.phase == .ended || event.phase == .cancelled {
                            self.hasTurnedPageInCurrentSwipe = false
                            // 끝났을 때 임계치를 넘지 못했다면 원래 자리로 튕겨 돌아가기
                            if self.swipeOffset != 0 {
                                DispatchQueue.main.async {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        self.swipeOffset = 0
                                        self.scrollAccumulatorX = 0
                                    }
                                }
                            }
                        }
                        
                        return nil
                    }
                }
                return event
            }
            
            // 1. 키코드 기반 처리 (물리적 키 위치: 한글/영문 입력기 종류에 상관없이 100% 동일하게 동작)
            switch event.keyCode {
            case 123: // ← 왼쪽 방향키
                if event.modifierFlags.contains(.command) {
                    self.currentIndex = self.isRightToLeft ? self.totalPages - 1 : 0
                    self.updateCurrentPages()
                    return nil
                }
                if self.canPanHorizontally {
                    if !self.heldMovementKeys.contains(123) {
                        self.heldMovementKeys.insert(123)
                        self.pan(dx: 24, dy: 0, animated: false)
                        self.startContinuousMovementTimer()
                    }
                    return nil
                } else {
                    self.turnPage(forward: self.isRightToLeft)
                    return nil
                }
            case 124: // → 오른쪽 방향키
                if event.modifierFlags.contains(.command) {
                    self.currentIndex = self.isRightToLeft ? 0 : self.totalPages - 1
                    self.updateCurrentPages()
                    return nil
                }
                if self.canPanHorizontally {
                    if !self.heldMovementKeys.contains(124) {
                        self.heldMovementKeys.insert(124)
                        self.pan(dx: -24, dy: 0, animated: false)
                        self.startContinuousMovementTimer()
                    }
                    return nil
                } else {
                    self.turnPage(forward: !self.isRightToLeft)
                    return nil
                }
            case 125: // ↓ 아래 방향키
                if self.isZoomed {
                    if !self.heldMovementKeys.contains(125) {
                        self.heldMovementKeys.insert(125)
                        self.pan(dx: 0, dy: -24, animated: false)
                        self.startContinuousMovementTimer()
                    }
                    return nil
                } else if self.isFitToWidth {
                    if !self.heldMovementKeys.contains(125) {
                        self.heldMovementKeys.insert(125)
                        self.scrollContinuousAction?(24)
                        self.startContinuousMovementTimer()
                    }
                    return nil
                }
            case 126: // ↑ 위 방향키
                if self.isZoomed {
                    if !self.heldMovementKeys.contains(126) {
                        self.heldMovementKeys.insert(126)
                        self.pan(dx: 0, dy: 24, animated: false)
                        self.startContinuousMovementTimer()
                    }
                    return nil
                } else if self.isFitToWidth {
                    if !self.heldMovementKeys.contains(126) {
                        self.heldMovementKeys.insert(126)
                        self.scrollContinuousAction?(-24)
                        self.startContinuousMovementTimer()
                    }
                    return nil
                }
            case 27: // - 키 (알파벳 상단 키패드 - 축소)
                if !event.modifierFlags.contains(.command) {
                    self.zoomOut()
                    return nil
                }
            case 24: // = / + 키 (알파벳 상단 키패드 - 확대)
                if !event.modifierFlags.contains(.command) {
                    self.zoomIn()
                    return nil
                }
            case 29: // 0 키 (알파벳 상단 키패드 - 배율 초기화)
                if !event.modifierFlags.contains(.command) {
                    self.resetZoom()
                    return nil
                }
            case 53: // Esc 키 (전체화면 상태를 유지하면서 책장으로 돌아가기)
                self.dismissAction?()
                return nil
            case 3: // F 키 (영문 F / 한글 ㄹ) - 전체화면
                if !event.modifierFlags.contains(.command) {
                    let targetWindow = self.window ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isKeyWindow })
                    if let targetWindow = targetWindow {
                        targetWindow.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
                        targetWindow.styleMask.insert([.titled, .resizable, .closable, .miniaturizable])
                        DispatchQueue.main.async {
                            targetWindow.toggleFullScreen(nil)
                        }
                    }
                    return nil
                }
            case 43: // , 키 (쉼표) - 이전장/다음장 전환 (확대 상태에서도 동작)
                if !event.modifierFlags.contains(.command) {
                    self.turnPage(forward: self.isRightToLeft)
                    return nil
                }
            case 47: // . 키 (마침표) - 이전장/다음장 전환 (확대 상태에서도 동작)
                if !event.modifierFlags.contains(.command) {
                    self.turnPage(forward: !self.isRightToLeft)
                    return nil
                }
            case 9: // V 키 (영문 V / 한글 ㅍ) - 세로 맞춤
                if !event.modifierFlags.contains(.command) {
                    self.isFitToWidth = false
                    return nil
                }
            case 4: // H 키 (영문 H / 한글 ㅗ) - 가로 맞춤
                if !event.modifierFlags.contains(.command) {
                    self.isFitToWidth = true
                    return nil
                }
            case 33: // [ 키 (영문 [ / 한글 ㅐ) - 이전 파일
                if !event.modifierFlags.contains(.command) {
                    self.changeBook(forward: false)
                    return nil
                }
            case 30: // ] 키 (영문 ] / 한글 ㅔ) - 다음 파일
                if !event.modifierFlags.contains(.command) {
                    self.changeBook(forward: true)
                    return nil
                }
            case 44: // / 키 (슬래시) - 스마트 줌 토글
                if !event.modifierFlags.contains(.command) {
                    self.toggleSmartZoom()
                    return nil
                }
            default:
                break
            }
            
            // 2. 문자 기반 보완 처리 (한글 입력기 상태 지원 및 기호 지원)
            // Cmd 키가 눌려 있으면 시스템 메뉴 단축키로 넘긴다 (Cmd+H 등)
            if event.modifierFlags.contains(.command) {
                return event
            }
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
                case "/", "?":
                    self.toggleSmartZoom()
                    return nil
                default:
                    break
                }
            }
            
            return event
        }
    }
    
    func removeKeyMonitor() {
        stopContinuousMovementTimer()
        heldMovementKeys.removeAll()
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
            
            if currentIndex >= totalPages && totalPages > 0 {
                currentIndex = totalPages - 1
            }
            
            if totalPages > 0 {
                updateCurrentPages()
            }
        } catch {
            print("Failed to load entries: \(error)")
        }
    }
    
    func turnPage(forward: Bool) {
        // 현재 보여지고 있는 실제 장수를 기준으로 인덱스 이동
        let step = currentPages.count > 0 ? currentPages.count : (isTwoPageMode ? 2 : 1)
        
        // 방향 계산 (isRightToLeft가 참이면 forward가 왼쪽으로 가는 것(페이지 증가))
        var nextIndex = currentIndex
        
        if forward {
            nextIndex += step
        } else {
            // 뒤로 갈 때는 무조건 앞의 짝수로 이동하되(isTwoPageMode), 정확한 이전 페이지 장수를 모를 수 있으므로 일단 2 감소 후 홀/짝 보정
            let backStep = isTwoPageMode ? 2 : 1
            nextIndex -= backStep
            
            if isTwoPageMode && nextIndex % 2 != 0 {
                nextIndex -= 1
            }
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
        adjustPanOffsetForPageTurn(forward: forward)
        adjustFitToWidthForPageTurn(forward: forward)
    }
    
    func adjustPanOffsetForPageTurn(forward: Bool) {
        guard isZoomed else {
            panOffset = .zero
            return
        }
        
        let maxOffset = maxPanOffset()
        let targetY: CGFloat
        if forward {
            // 다음 페이지로 이동할 경우: 최상단
            targetY = maxOffset.height
        } else {
            // 이전 페이지로 이동할 경우: 설정에 따라 최하단 또는 최상단
            targetY = (prevPageZoomPosition == .bottom) ? -maxOffset.height : maxOffset.height
        }
        
        panOffset = CGSize(width: 0, height: targetY)
    }
    
    func adjustFitToWidthForPageTurn(forward: Bool) {
        guard isFitToWidth else { return }
        if forward {
            // 다음 페이지: 최상단 스크롤
            scrollToTop()
        } else {
            // 이전 페이지: 설정에 따라 최하단 또는 최상단 스크롤
            if prevPageZoomPosition == .bottom {
                scrollToBottom()
            } else {
                scrollToTop()
            }
        }
    }
    
    private func showVolumeOverlay(message: String) {
        volumeOverlayMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.volumeOverlayMessage == message {
                self.volumeOverlayMessage = nil
            }
        }
    }
    
    func getPages(for index: Int) -> [ComicPage] {
        guard index >= 0 && index < totalPages else { return [] }
        
        var newPages: [ComicPage] = []
        let page1 = getPage(at: index)
        newPages.append(page1)
        
        if isTwoPageMode {
            if let img = page1.image, img.size.width > img.size.height {
                // 가로형 스프레드 감지 (예외 처리)
            } else if index + 1 < totalPages {
                let page2 = getPage(at: index + 1)
                if let img2 = page2.image, img2.size.width > img2.size.height {
                    // 예외
                } else {
                    newPages.append(page2)
                }
            }
        }
        
        if newPages.count == 2 {
            if (isRightToLeft && !isSpreadInverted) || (!isRightToLeft && isSpreadInverted) {
                newPages.swapAt(0, 1)
            }
        }
        
        return newPages
    }
    
    func updateCurrentPages() {
        guard currentIndex < totalPages else { return }
        
        // 현재 페이지
        self.currentPages = getPages(for: currentIndex)
        
        // 다음 페이지 (현재 표시된 페이지 수만큼 인덱스 증가)
        let nextIdx = currentIndex + self.currentPages.count
        self.nextPages = nextIdx < totalPages ? getPages(for: nextIdx) : []
        
        // 이전 페이지 (정확히 몇 페이지 이전인지 알기 어렵지만, isTwoPageMode일 땐 보통 2 감소)
        // currentIndex는 항상 짝수/홀수 규칙을 따르므로 -step을 사용 (단, 이전 페이지가 스프레드일 수 있음)
        let prevStep = isTwoPageMode ? 2 : 1
        let prevIdx = currentIndex - prevStep
        self.prevPages = prevIdx >= 0 ? getPages(for: prevIdx) : []
        
        // 캐시 관리
        manageCache()
    }
    
    func scrollToTop() {
        DispatchQueue.main.async {
            self.scrollToTopAction?()
        }
    }
    
    func scrollToBottom() {
        DispatchQueue.main.async {
            self.scrollToBottomAction?()
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
            self.autoContrast = UserDefaults.standard.bool(forKey: "autoContrast_\(self.book.id)")
            self.loadEntries()
            
            showVolumeOverlay(message: self.book.title)
        } else {
            showVolumeOverlay(message: forward ? "마지막 권입니다." : "첫 권입니다.")
        }
    }
}

// MARK: - Sharpen Level Enum
enum SharpenLevel: String, CaseIterable, Identifiable {
    case off = "끄기"
    case low = "약하게"
    case medium = "보통"
    case high = "강하게"
    
    var id: String { rawValue }
    
    var intensity: Float {
        switch self {
        case .off: return 0.0
        case .low: return 0.4
        case .medium: return 0.8
        case .high: return 1.4
        }
    }
}

// MARK: - 확대 시 이전 페이지 위치 Enum
enum ZoomPrevPagePosition: String, CaseIterable, Identifiable {
    case bottom = "bottom"
    case top = "top"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .bottom: return "최하단"
        case .top: return "최상단"
        }
    }
}
