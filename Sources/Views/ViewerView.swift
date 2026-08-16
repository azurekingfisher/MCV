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
                // 좌우 클릭으로 페이지 전환 (읽는 방향 설정 반영)
                .onTapGesture { location in
                    let isRightSide = location.x > geometry.size.width / 2
                    let forward = viewModel.isRightToLeft ? !isRightSide : isRightSide
                    viewModel.turnPage(forward: forward)
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
                            LanczosImageView(image: image, sharpenIntensity: viewModel.sharpenLevel.intensity, autoContrast: viewModel.autoContrast)
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
            
            // 설정 메뉴 (단면/양면, 샤픈 등)
            Menu {
                Toggle("가로로 꽉 차게 보기 (H)", isOn: $viewModel.isFitToWidth)
                Toggle("양면 보기", isOn: $viewModel.isTwoPageMode)
                Toggle("오른쪽에서 왼쪽으로 읽기", isOn: $viewModel.isRightToLeft)
                if viewModel.isTwoPageMode {
                    Toggle("좌우 반전", isOn: $viewModel.isSpreadInverted)
                }
                
                Divider()
                
                Menu("선명도 (샤픈 필터)") {
                    ForEach(SharpenLevel.allCases) { level in
                        Button(action: {
                            viewModel.sharpenLevel = level
                        }) {
                            HStack {
                                Text(level.rawValue)
                                if viewModel.sharpenLevel == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Toggle("대비 개선 모드", isOn: $viewModel.autoContrast)
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
        // 이미 viewDidMoveToWindow에서 설정되었으므로 updateNSView에서는 상태를 변경하지 않음 (무한 루프 방지)
    }
}

// MARK: - Lanczos & Anti-Aliased High Quality Image View with GPU Processing
final class LanczosNSImageView: NSView {
    var image: NSImage? {
        didSet { if image != oldValue { processImage() } }
    }
    var sharpenIntensity: Float = 0.0 {
        didSet { if sharpenIntensity != oldValue { processImage() } }
    }
    var autoContrast: Bool = false {
        didSet { if autoContrast != oldValue { processImage() } }
    }
    
    private var processedImage: NSImage?
    private var processingWorkItem: DispatchWorkItem?
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    private func processImage() {
        processingWorkItem?.cancel()
        
        guard let sourceImage = image else {
            self.processedImage = nil
            self.needsDisplay = true
            return
        }
        
        // 필터가 필요 없는 경우 원본 바로 사용
        if sharpenIntensity <= 0 && !autoContrast {
            self.processedImage = sourceImage
            self.needsDisplay = true
            return
        }
        
        let intensity = sharpenIntensity
        let applyContrast = autoContrast
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            var ciImage = CIImage(cgImage: cgImage)
            
            // 1. 대비 개선 필터 (Auto Contrast)
            if applyContrast {
                // 고속 검출을 위해 다운샘플링
                let scale: CGFloat = min(200.0 / ciImage.extent.width, 200.0 / ciImage.extent.height, 1.0)
                let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                
                if let minMaxFilter = CIFilter(name: "CIAreaMinMax") {
                    minMaxFilter.setValue(scaledImage, forKey: kCIInputImageKey)
                    minMaxFilter.setValue(CIVector(cgRect: scaledImage.extent), forKey: kCIInputExtentKey)
                    
                    if let minMaxImage = minMaxFilter.outputImage {
                        var pixels = [UInt8](repeating: 0, count: 8) // 2x1 픽셀 (RGBA8)
                        LanczosNSImageView.ciContext.render(minMaxImage, toBitmap: &pixels, rowBytes: 8, bounds: CGRect(x: 0, y: 0, width: 2, height: 1), format: .RGBA8, colorSpace: nil)
                        
                        let minR = CGFloat(pixels[0]) / 255.0
                        let minG = CGFloat(pixels[1]) / 255.0
                        let minB = CGFloat(pixels[2]) / 255.0
                        let maxR = CGFloat(pixels[4]) / 255.0
                        let maxG = CGFloat(pixels[5]) / 255.0
                        let maxB = CGFloat(pixels[6]) / 255.0
                        
                        let minLuma = minR * 0.299 + minG * 0.587 + minB * 0.114
                        let maxLuma = maxR * 0.299 + maxG * 0.587 + maxB * 0.114
                        
                        if maxLuma > minLuma {
                            let stretchScale = 1.0 / (maxLuma - minLuma)
                            let offset = -minLuma * stretchScale
                            
                            if let colorMatrix = CIFilter(name: "CIColorMatrix") {
                                colorMatrix.setValue(ciImage, forKey: kCIInputImageKey)
                                colorMatrix.setValue(CIVector(x: stretchScale, y: 0, z: 0, w: 0), forKey: "inputRVector")
                                colorMatrix.setValue(CIVector(x: 0, y: stretchScale, z: 0, w: 0), forKey: "inputGVector")
                                colorMatrix.setValue(CIVector(x: 0, y: 0, z: stretchScale, w: 0), forKey: "inputBVector")
                                colorMatrix.setValue(CIVector(x: offset, y: offset, z: offset, w: 0), forKey: "inputBiasVector")
                                
                                if let output = colorMatrix.outputImage {
                                    ciImage = output
                                }
                            }
                        }
                    }
                }
            }
            
            // 2. 샤픈 필터
            if intensity > 0 {
                if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
                    sharpenFilter.setValue(ciImage, forKey: kCIInputImageKey)
                    sharpenFilter.setValue(intensity, forKey: kCIInputSharpnessKey)
                    if let output = sharpenFilter.outputImage {
                        ciImage = output
                    }
                }
            }
            
            // 3. 최종 이미지 캐싱
            if let outputCGImage = LanczosNSImageView.ciContext.createCGImage(ciImage, from: ciImage.extent) {
                let finalImage = NSImage(cgImage: outputCGImage, size: sourceImage.size)
                DispatchQueue.main.async {
                    if let currentItem = self?.processingWorkItem, !currentItem.isCancelled {
                        self?.processedImage = finalImage
                        self?.needsDisplay = true
                    }
                }
            }
        }
        
        self.processingWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // 캐싱된 이미지가 렌더링 중이면 원본 이미지를 우선 표시
        let displayImage = processedImage ?? image
        guard let imageToDraw = displayImage, let context = NSGraphicsContext.current else { return }
        
        context.imageInterpolation = .high
        context.shouldAntialias = true
        
        let targetRect = self.bounds
        guard targetRect.width > 0 && targetRect.height > 0 else { return }
        
        imageToDraw.draw(in: targetRect)
    }
}

struct LanczosImageView: NSViewRepresentable {
    let image: NSImage
    var sharpenIntensity: Float = 0.0
    var autoContrast: Bool = false
    
    func makeNSView(context: Context) -> LanczosNSImageView {
        let view = LanczosNSImageView()
        view.image = image
        view.sharpenIntensity = sharpenIntensity
        view.autoContrast = autoContrast
        return view
    }
    
    func updateNSView(_ nsView: LanczosNSImageView, context: Context) {
        if nsView.image != image {
            nsView.image = image
        }
        if nsView.sharpenIntensity != sharpenIntensity {
            nsView.sharpenIntensity = sharpenIntensity
        }
        if nsView.autoContrast != autoContrast {
            nsView.autoContrast = autoContrast
        }
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
