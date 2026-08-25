import SwiftUI
import AppKit

// MARK: - App Delegate (정식 macOS 앱 동작 및 아이콘/버전 설정)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // mcv_icon.png 적용 (Dock 및 About 창 공통)
        if let iconURL = Bundle.module.url(forResource: "mcv_icon", withExtension: "png") ?? locateIconURL(),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow {
                // 메뉴 창, 팝업, 헬프 검색창 등 보조 윈도우는 스타일을 수정하지 않음
                guard !(window is NSPanel),
                      window.level == .normal,
                      window.styleMask.contains(.titled),
                      !window.className.contains("Menu"),
                      !window.className.contains("Pop") else { return }
                window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
                window.styleMask.insert([.titled, .resizable, .closable, .miniaturizable])
            }
        }
    }
    
    private func locateIconURL() -> URL? {
        let path = "/Users/igyeongseob/Coding/MCV/mcv_icon.png"
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}

@main
struct MCVApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)
        .commands {
            ViewerCommands(openWindow: openWindow)
        }
        
        Window("MCV 도움말", id: "help") {
            HelpView()
        }
        
        Window("개선 사항", id: "releaseNotes") {
            ReleaseNotesView()
        }
    }
}

// MARK: - 뷰어 키보드 단축키 및 정보 메뉴 (앱 메뉴 시스템)
struct ViewerCommands: Commands {
    var openWindow: OpenWindowAction
    
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("MCV 정보") {
                var options: [NSApplication.AboutPanelOptionKey: Any] = [
                    .applicationName: "MCV",
                    .applicationVersion: "1.5.7",
                    .version: "1.5.7",
                    .credits: NSAttributedString(
                        string: "macOS 만화책 뷰어 v1.5.7",
                        attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
                    )
                ]
                if let icon = NSApp.applicationIconImage {
                    options[.applicationIcon] = icon
                }
                NSApp.orderFrontStandardAboutPanel(options: options)
            }
        }
        
        CommandGroup(replacing: .newItem) {
            Button("폴더 열기...") {
                if ViewerViewModel.current == nil {
                    LibraryViewModel.current?.selectFolder()
                }
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(ViewerViewModel.current != nil)
        }
        
        CommandGroup(replacing: .appVisibility) {
            Button("창 숨기기/표시하기") {
                let targetWindow = ViewerViewModel.current?.window ?? NSApp.keyWindow ?? NSApp.windows.first(where: { $0.title != "MCV 도움말" && $0.className != "NSStatusBarWindow" })
                if let window = targetWindow {
                    if window.isVisible {
                        window.orderOut(nil)
                    } else {
                        window.makeKeyAndOrderFront(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
            .keyboardShortcut("h", modifiers: [.command])
        }
        
        CommandMenu("뷰어") {
            Button("이전 페이지") {
                guard let vm = ViewerViewModel.current else { return }
                vm.turnPage(forward: vm.isRightToLeft)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            
            Button("다음 페이지") {
                guard let vm = ViewerViewModel.current else { return }
                vm.turnPage(forward: !vm.isRightToLeft)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            
            Divider()
            
            Button("전체화면 전환") {
                NSApp.sendAction(#selector(NSWindow.toggleFullScreen(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("f", modifiers: [])
            
            Button("세로 맞춤 보기") {
                ViewerViewModel.current?.isFitToWidth = false
            }
            .keyboardShortcut("v", modifiers: [])
            
            Button("가로 맞춤 보기") {
                ViewerViewModel.current?.isFitToWidth = true
            }
            
            Divider()
            
            Button("이전 파일") {
                ViewerViewModel.current?.changeBook(forward: false)
            }
            .keyboardShortcut("[", modifiers: [])
            
            Button("다음 파일") {
                ViewerViewModel.current?.changeBook(forward: true)
            }
            .keyboardShortcut("]", modifiers: [])
            
            Divider()
            
            Button("책장으로 돌아가기") {
                ViewerViewModel.current?.dismissAction?()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        
        CommandGroup(replacing: .help) {
            Button("MCV 도움말 보기") {
                openWindow(id: "help")
            }
            Button("개선 사항") {
                openWindow(id: "releaseNotes")
            }
        }
    }
}
