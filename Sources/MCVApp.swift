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
    
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentMinSize)
        .commands {
            ViewerCommands()
        }
    }
}

// MARK: - 뷰어 키보드 단축키 및 정보 메뉴 (앱 메뉴 시스템)
struct ViewerCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("MCV 정보") {
                var options: [NSApplication.AboutPanelOptionKey: Any] = [
                    .applicationName: "MCV",
                    .applicationVersion: "1.0",
                    .version: "1.0.0",
                    .credits: NSAttributedString(
                        string: "macOS 만화책 뷰어 v1.0",
                        attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
                    )
                ]
                if let icon = NSApp.applicationIconImage {
                    options[.applicationIcon] = icon
                }
                NSApp.orderFrontStandardAboutPanel(options: options)
            }
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
            .keyboardShortcut("h", modifiers: [])
            
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
                if let window = NSApp.windows.first(where: { $0.isKeyWindow }), window.styleMask.contains(.fullScreen) {
                    NSApp.sendAction(#selector(NSWindow.toggleFullScreen(_:)), to: nil, from: nil)
                }
                ViewerViewModel.current?.dismissAction?()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
    }
}
