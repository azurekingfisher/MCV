import SwiftUI

struct ViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ViewerViewModel
    
    init(book: ComicBook, allBooks: [ComicBook] = []) {
        _viewModel = StateObject(wrappedValue: ViewerViewModel(book: book, allBooks: allBooks))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 메인 뷰어 영역
            GeometryReader { geometry in
                Group {
                    if viewModel.isFitToWidth {
                        FitToWidthScrollView(viewModel: viewModel) {
                            viewerContent(geometry: geometry)
                        }
                    } else {
                        viewerContent(geometry: geometry)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(viewModel.panOffset)
                .scaleEffect(viewModel.scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            viewModel.scale = max(0.5, min(4.0, value.magnitude))
                        }
                )
                // 좌우 클릭으로 페이지 전환
                .onTapGesture { location in
                    let isRightSide = location.x > geometry.size.width / 2
                    viewModel.turnPage(forward: isRightSide)
                }
            }
            
            // 볼륨 이동 오버레이
            if let overlayMessage = viewModel.volumeOverlayMessage {
                Text(overlayMessage)
                    .font(.title2)
                    .padding(30)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .transition(.opacity)
                    .zIndex(10)
            }
            
            // 하단 감지 영역 및 컨트롤
            VStack {
                Spacer()
                
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                        .frame(height: 120)
                    
                    if viewModel.isControlsVisible {
                        bottomBar
                            .padding(.bottom, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isControlsVisible = hovering
                    }
                }
            }
        }
        .toolbar(.hidden)
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea()
        .background(WindowAccessor { window in
            window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
            window.styleMask.insert([.titled, .resizable, .closable, .miniaturizable])
            viewModel.window = window
        })
        .onAppear {
            ViewerViewModel.current = viewModel
            viewModel.installKeyMonitor {
                dismiss()
            }
        }
        .onDisappear {
            ViewerViewModel.current = nil
            viewModel.removeKeyMonitor()
        }
    }
    
    @ViewBuilder
    private func viewerContent(geometry: GeometryProxy) -> some View {
        ZStack {
            if let combinedRatio = getCombinedAspectRatio(pages: viewModel.currentPages) {
                HStack(spacing: 0) {
                    ForEach(viewModel.currentPages) { page in
                        if let image = page.image, image.size.height > 0 {
                            LanczosImageView(image: image)
                                .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .aspectRatio(combinedRatio, contentMode: .fit)
                .frame(width: viewModel.isFitToWidth ? geometry.size.width : nil)
            } else {
                ProgressView()
            }
        }
    }
    
    private func getCombinedAspectRatio(pages: [ComicPage]) -> CGFloat? {
        guard !pages.isEmpty else { return nil }
        var totalRatio: CGFloat = 0
        for page in pages {
            if let image = page.image, image.size.height > 0 {
                totalRatio += image.size.width / image.size.height
            }
        }
        return totalRatio > 0 ? totalRatio : nil
    }
    
    private var bottomBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 스크러버 (타임라인)
            Slider(
                value: Binding(
                    get: { Double(viewModel.currentIndex) },
                    set: { viewModel.seek(to: Int($0)) }
                ),
                in: 0...Double(max(0, viewModel.totalPages - 1)),
                step: 1
            )
            .tint(.white)
            .padding(.horizontal)
            
            Text("\(viewModel.currentIndex + 1) / \(viewModel.totalPages)")
                .foregroundColor(.white)
                .monospacedDigit()
            
            Spacer()
            
            // 설정 메뉴 (단면/양면 등)
            Menu {
                Toggle("가로로 꽉 차게 보기 (H)", isOn: $viewModel.isFitToWidth)
                Toggle("양면 보기", isOn: $viewModel.isTwoPageMode)
                Toggle("오른쪽에서 왼쪽으로 읽기", isOn: $viewModel.isRightToLeft)
                if viewModel.isTwoPageMode {
                    Toggle("좌우 반전", isOn: $viewModel.isSpreadInverted)
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .padding(.horizontal, 40)
    }
}

// MARK: - Helper to access NSWindow
final class CustomWindowNSView: NSView {
    var callback: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            callback?(window)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> CustomWindowNSView {
        let view = CustomWindowNSView()
        view.callback = callback
        return view
    }

    func updateNSView(_ nsView: CustomWindowNSView, context: Context) {
        if let window = nsView.window {
            callback(window)
        }
    }
}

// MARK: - Lanczos & Anti-Aliased High Quality Image View
final class LanczosNSImageView: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image = image, let context = NSGraphicsContext.current else { return }
        
        // 안티앨리어싱 및 Lanczos (High Quality) 보간법 설정
        context.imageInterpolation = .high
        context.shouldAntialias = true
        
        let targetRect = self.bounds
        guard targetRect.width > 0 && targetRect.height > 0 else { return }
        
        // AppKit 표준 드로잉: 좌표계 왜곡 없이 Lanczos 보간법으로 그리기
        image.draw(in: targetRect)
    }
}

struct LanczosImageView: NSViewRepresentable {
    let image: NSImage
    
    func makeNSView(context: Context) -> LanczosNSImageView {
        let view = LanczosNSImageView()
        view.image = image
        return view
    }
    
    func updateNSView(_ nsView: LanczosNSImageView, context: Context) {
        nsView.image = image
    }
}

// MARK: - Fit to Width ScrollView with Keyboard Arrow Support
struct FitToWidthScrollView<Content: View>: NSViewRepresentable {
    @ObservedObject var viewModel: ViewerViewModel
    let content: Content

    init(viewModel: ViewerViewModel, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = hostingView

        if let contentView = scrollView.documentView {
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor)
            ])
        }

        context.coordinator.setupScrollAction(for: scrollView, viewModel: viewModel)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
        context.coordinator.setupScrollAction(for: nsView, viewModel: viewModel)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        func setupScrollAction(for scrollView: NSScrollView, viewModel: ViewerViewModel) {
            viewModel.scrollAction = { [weak scrollView] deltaY in
                guard let scrollView = scrollView else { return }
                let contentView = scrollView.contentView
                var currentPoint = contentView.bounds.origin
                currentPoint.y += deltaY

                if let documentView = scrollView.documentView {
                    let maxY = max(0, documentView.bounds.height - contentView.bounds.height)
                    currentPoint.y = max(0, min(currentPoint.y, maxY))
                }

                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.15
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    contentView.animator().setBoundsOrigin(currentPoint)
                    scrollView.reflectScrolledClipView(contentView)
                }
            }

            viewModel.scrollToTopAction = { [weak scrollView] in
                guard let scrollView = scrollView else { return }
                let contentView = scrollView.contentView
                contentView.scroll(to: NSPoint(x: 0, y: 0))
                scrollView.reflectScrolledClipView(contentView)
            }
        }
    }
}
