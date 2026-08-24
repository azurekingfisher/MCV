import SwiftUI

struct ViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ViewerViewModel
    @State private var dragStartPanOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @AppStorage("smartZoomRatio") private var smartZoomRatio: Double = 2.0
    
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
                .scaleEffect(viewModel.scale)
                .offset(viewModel.panOffset)
                .onAppear {
                    viewModel.viewportSize = geometry.size
                }
                .onChange(of: geometry.size) { newSize in
                    viewModel.viewportSize = newSize
                    viewModel.panOffset = viewModel.clampPanOffset(viewModel.panOffset)
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = max(0.5, min(4.0, value.magnitude))
                            viewModel.scale = newScale
                            viewModel.panOffset = viewModel.clampPanOffset(viewModel.panOffset, for: newScale)
                        }
                        .simultaneously(with: DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if viewModel.isZoomed {
                                    if !isDragging {
                                        isDragging = true
                                        dragStartPanOffset = viewModel.panOffset
                                    }
                                    let rawOffset = CGSize(
                                        width: dragStartPanOffset.width + value.translation.width,
                                        height: dragStartPanOffset.height + value.translation.height
                                    )
                                    viewModel.panOffset = viewModel.clampPanOffset(rawOffset)
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                dragStartPanOffset = .zero
                            }
                        )
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
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 18)
                    .liquidGlass(cornerRadius: 18)
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
        .navigationTitle(viewModel.book.title)
        .toolbar(.hidden)
        .navigationBarBackButtonHidden(true)
        .background(WindowAccessor { window in
            window.collectionBehavior = [.fullScreenPrimary, .fullScreenAllowsTiling]
            window.styleMask.insert([.titled, .resizable, .closable, .miniaturizable])
            window.title = viewModel.book.title
            viewModel.window = window
        })
        .onChange(of: viewModel.book.title) { newTitle in
            viewModel.window?.title = newTitle
        }
        .onAppear {
            ViewerViewModel.current = viewModel
            viewModel.window?.title = viewModel.book.title
            viewModel.installKeyMonitor {
                dismiss()
            }
        }
        .onDisappear {
            ViewerViewModel.current = nil
            viewModel.removeKeyMonitor()
            viewModel.window?.title = "MCV 책장"
        }
    }
    
    @ViewBuilder
    private func viewerContent(geometry: GeometryProxy) -> some View {
        if viewModel.isFitToWidth {
            // 가로 꽉 차기 모드: 불필요한 이전/다음 페이지 생성 배제, 현재 페이지만 단독 고속 렌더링
            pageGroupView(pages: viewModel.currentPages, geometry: geometry)
        } else {
            let w = geometry.size.width
            ZStack {
                // 1. 이전 페이지 (isRightToLeft면 오른쪽, 아니면 왼쪽)
                let prevOffset: CGFloat = viewModel.isRightToLeft ? w : -w
                pageGroupView(pages: viewModel.prevPages, geometry: geometry)
                    .offset(x: prevOffset + viewModel.swipeOffset)
                    .opacity(viewModel.isZoomed ? 0 : 1)
                
                // 2. 현재 페이지 (중앙)
                pageGroupView(pages: viewModel.currentPages, geometry: geometry)
                    .offset(x: viewModel.swipeOffset)
                
                // 3. 다음 페이지 (isRightToLeft면 왼쪽, 아니면 오른쪽)
                let nextOffset: CGFloat = viewModel.isRightToLeft ? -w : w
                pageGroupView(pages: viewModel.nextPages, geometry: geometry)
                    .offset(x: nextOffset + viewModel.swipeOffset)
                    .opacity(viewModel.isZoomed ? 0 : 1)
            }
        }
    }
    
    @ViewBuilder
    private func pageGroupView(pages: [ComicPage], geometry: GeometryProxy) -> some View {
        if pages.isEmpty {
            Color.clear
        } else if let combinedRatio = getCombinedAspectRatio(pages: pages) {
            let fitHeight = geometry.size.width / combinedRatio
            HStack(spacing: 0) {
                ForEach(pages) { page in
                    let displayCG = page.cgImage ?? page.thumbnailCGImage
                    let displayImg = page.image ?? (displayCG != nil ? NSImage(cgImage: displayCG!, size: page.size) : nil)
                    
                    if let image = displayImg, page.size.height > 0 {
                        LanczosImageView(image: image, cgImage: displayCG, sharpenIntensity: viewModel.effectiveSharpenIntensity, autoContrast: viewModel.effectiveAutoContrast)
                            .aspectRatio(page.size.width / page.size.height, contentMode: .fit)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .aspectRatio(combinedRatio, contentMode: .fit)
            .frame(width: viewModel.isFitToWidth ? geometry.size.width : nil,
                   height: viewModel.isFitToWidth ? fitHeight : nil)
            .frame(maxWidth: viewModel.isFitToWidth ? nil : geometry.size.width,
                   maxHeight: viewModel.isFitToWidth ? nil : geometry.size.height)
        } else {
            ProgressView()
        }
    }
    
    private func getCombinedAspectRatio(pages: [ComicPage]) -> CGFloat? {
        guard !pages.isEmpty else { return nil }
        var totalRatio: CGFloat = 0
        for page in pages {
            if page.size.height > 0 {
                totalRatio += page.size.width / page.size.height
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
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding()
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 스크러버 (타임라인)
            let maxSliderPage = max(1, viewModel.totalPages - 1)
            Slider(
                value: Binding(
                    get: { Double(min(viewModel.currentIndex, maxSliderPage)) },
                    set: { viewModel.seek(to: Int($0)) }
                ),
                in: 0...Double(maxSliderPage),
                step: 1,
                onEditingChanged: { isEditing in
                    viewModel.isScrubbing = isEditing
                }
            )
            .disabled(viewModel.totalPages <= 1)
            .tint(.white)
            .padding(.horizontal)
            
            Text("\(viewModel.currentIndex + 1) / \(viewModel.totalPages)")
                .foregroundColor(.white)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
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
                
                Menu("스마트 줌 확대 비율") {
                    ForEach([1.5, 2.0, 3.0], id: \.self) { ratio in
                        Button(action: {
                            smartZoomRatio = ratio
                        }) {
                            HStack {
                                Text("\(Int(ratio * 100))%")
                                if smartZoomRatio == ratio {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Menu("이전 페이지 이동 시 위치") {
                    ForEach(ZoomPrevPagePosition.allCases) { pos in
                        Button(action: {
                            viewModel.prevPageZoomPosition = pos
                        }) {
                            HStack {
                                Text(pos.title)
                                if viewModel.prevPageZoomPosition == pos {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding()
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .liquidGlassCapsule()
        .padding(.horizontal, 40)
    }
}

// MARK: - Liquid Glass Optical Lens Style Modifier (Capsule)
struct LiquidGlassCapsuleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        let shape = Capsule()

        content
            .background {
                if reduceTransparency {
                    shape
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                        .overlay(
                            shape.strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                } else {
                    ZStack {
                        // 1. 투명도를 높이고 블러를 가볍게 한 맑은 글래스 베이스 (Reduced blur / High clarity glass)
                        shape
                            .fill(.ultraThinMaterial.opacity(0.6))
                        
                        // 2. 렌즈 내부의 빛 투과 틴트 (Ambient Light Transmission Tint)
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.black.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // 3. 렌즈 곡면 반사 하이라이트 (Convex Lens Top Sheen)
                        VStack(spacing: 0) {
                            shape
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.25),
                                            Color.white.opacity(0.04),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 24)
                            Spacer(minLength: 0)
                        }
                    }
                    .clipShape(shape)
                    .overlay(
                        // 4. 완벽하게 일치하는 단일 광학 굴절 및 스페큘러 테두리 (Single Unified Specular & Optical Refraction Border)
                        shape
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.95), location: 0.0),
                                        .init(color: Color(red: 0.82, green: 0.93, blue: 1.0).opacity(0.65), location: 0.25),
                                        .init(color: Color.white.opacity(0.15), location: 0.5),
                                        .init(color: Color.black.opacity(0.4), location: 0.8),
                                        .init(color: Color.white.opacity(0.35), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    // 5. 다층 광학 섀도우 (Multi-layer Optical Depth Shadows)
                    .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                }
            }
    }
}

// MARK: - Liquid Glass Optical Lens Style Modifier (RoundedRectangle)
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .circular)

        content
            .background {
                if reduceTransparency {
                    shape
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                        .overlay(
                            shape.strokeBorder(Color.black.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                } else {
                    ZStack {
                        shape
                            .fill(.ultraThinMaterial.opacity(0.6))
                        
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.black.opacity(0.2)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        VStack(spacing: 0) {
                            shape
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.25),
                                            Color.white.opacity(0.04),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: 24)
                            Spacer(minLength: 0)
                        }
                    }
                    .clipShape(shape)
                    .overlay(
                        shape
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.95), location: 0.0),
                                        .init(color: Color(red: 0.82, green: 0.93, blue: 1.0).opacity(0.65), location: 0.25),
                                        .init(color: Color.white.opacity(0.15), location: 0.5),
                                        .init(color: Color.black.opacity(0.4), location: 0.8),
                                        .init(color: Color.white.opacity(0.35), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                }
            }
    }
}

extension View {
    func liquidGlassCapsule() -> some View {
        self.modifier(LiquidGlassCapsuleModifier())
    }
    
    func liquidGlass(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
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

// MARK: - Lanczos & Anti-Aliased High Quality Image View with GPU Hardware Layer Acceleration
final class LanczosNSImageView: NSView {
    var image: NSImage? {
        didSet {
            if image != oldValue {
                updateImage()
            }
        }
    }
    var cgImage: CGImage? {
        didSet {
            if cgImage != oldValue {
                updateImage()
            }
        }
    }
    var sharpenIntensity: Float = 0.0 {
        didSet {
            if sharpenIntensity != oldValue {
                processImage()
            }
        }
    }
    var autoContrast: Bool = false {
        didSet {
            if autoContrast != oldValue {
                processImage()
            }
        }
    }
    
    private var processingWorkItem: DispatchWorkItem?
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .never
        self.layer?.contentsGravity = .resizeAspect
        self.layer?.isOpaque = true
    }
    
    private func updateImage() {
        let baseCG = cgImage ?? image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        self.layer?.contents = baseCG
        processImage()
    }
    
    private func processImage() {
        processingWorkItem?.cancel()
        
        guard let sourceCG = cgImage ?? image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            self.layer?.contents = nil
            return
        }
        
        // 필터가 필요 없는 경우 원본 바로 사용 (0ms 지연)
        if sharpenIntensity <= 0 && !autoContrast {
            self.layer?.contents = sourceCG
            return
        }
        
        let intensity = sharpenIntensity
        let applyContrast = autoContrast
        
        let workItem = DispatchWorkItem { [weak self] in
            var ciImage = CIImage(cgImage: sourceCG)
            
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
            
            // 3. 최종 이미지 GPU 렌더링 후 레이어에 즉시 설정
            if let outputCGImage = LanczosNSImageView.ciContext.createCGImage(ciImage, from: ciImage.extent) {
                DispatchQueue.main.async {
                    if let currentItem = self?.processingWorkItem, !currentItem.isCancelled {
                        self?.layer?.contents = outputCGImage
                    }
                }
            }
        }
        
        self.processingWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
}

struct LanczosImageView: NSViewRepresentable {
    let image: NSImage
    var cgImage: CGImage? = nil
    var sharpenIntensity: Float = 0.0
    var autoContrast: Bool = false
    
    func makeNSView(context: Context) -> LanczosNSImageView {
        let view = LanczosNSImageView()
        view.cgImage = cgImage
        view.image = image
        view.sharpenIntensity = sharpenIntensity
        view.autoContrast = autoContrast
        return view
    }
    
    func updateNSView(_ nsView: LanczosNSImageView, context: Context) {
        if nsView.cgImage != cgImage || nsView.image != image {
            nsView.cgImage = cgImage
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

// MARK: - Custom Medium Gray Overlay Scroller (흑백 만화 배경에서 최적의 가독성을 제공하는 중간 회색 스크롤바)
final class MediumGrayScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool {
        return true
    }
    
    override func drawKnob() {
        let knobRect = rect(for: .knob)
        guard !knobRect.isEmpty else { return }
        
        let path = NSBezierPath(roundedRect: knobRect.insetBy(dx: 2, dy: 1), xRadius: 3.5, yRadius: 3.5)
        
        // 1. 중간 명도의 회색 채우기 (흰색 컷과 검은색 컷 모두에서 뚜렷하게 식별됨)
        NSColor(white: 0.52, alpha: 0.88).setFill()
        path.fill()
        
        // 2. 미세한 대비 테두리 (경계선 식별 보조)
        NSColor(white: 0.2, alpha: 0.35).setStroke()
        path.lineWidth = 0.5
        path.stroke()
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
        let customScroller = MediumGrayScroller()
        scrollView.verticalScroller = customScroller
        scrollView.scrollerStyle = .overlay
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true

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
        nsView.scrollerStyle = .overlay
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

                contentView.scroll(to: currentPoint)
                scrollView.reflectScrolledClipView(contentView)
            }

            viewModel.scrollContinuousAction = { [weak scrollView] deltaY in
                guard let scrollView = scrollView else { return }
                let contentView = scrollView.contentView
                var currentPoint = contentView.bounds.origin
                currentPoint.y += deltaY

                if let documentView = scrollView.documentView {
                    let maxY = max(0, documentView.bounds.height - contentView.bounds.height)
                    currentPoint.y = max(0, min(currentPoint.y, maxY))
                }

                contentView.scroll(to: currentPoint)
                scrollView.reflectScrolledClipView(contentView)
            }

            viewModel.scrollToTopAction = { [weak scrollView] in
                guard let scrollView = scrollView else { return }
                DispatchQueue.main.async {
                    let contentView = scrollView.contentView
                    contentView.scroll(to: NSPoint(x: 0, y: 0))
                    scrollView.reflectScrolledClipView(contentView)
                }
            }
            
            viewModel.scrollToBottomAction = { [weak scrollView] in
                guard let scrollView = scrollView else { return }
                DispatchQueue.main.async {
                    if let documentView = scrollView.documentView {
                        documentView.layoutSubtreeIfNeeded()
                        let maxY = max(0, documentView.bounds.height - scrollView.contentView.bounds.height)
                        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                    }
                }
            }
        }
    }
}
