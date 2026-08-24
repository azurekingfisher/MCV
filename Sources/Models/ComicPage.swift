import Foundation
import AppKit
import ImageIO

/// 개별 만화 페이지 정보를 담는 모델
struct ComicPage: Identifiable, Hashable {
    let id: UUID = UUID()
    let index: Int
    let entryName: String
    var imageData: Data?
    
    // 저해상도 프록시 이미지 (빠른 탐색/스크러빙용 2ms 초고속 디코딩)
    var thumbnailCGImage: CGImage?
    
    // 원본 고해상도 이미지 (정지 상태용)
    var image: NSImage?
    var cgImage: CGImage?
    var size: CGSize = .zero
    var isFullLoaded: Bool = false
    
    init(index: Int, entryName: String, imageData: Data?, loadFullImmediately: Bool = true) {
        self.index = index
        self.entryName = entryName
        self.imageData = imageData
        
        guard let data = imageData else { return }
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            if let img = NSImage(data: data) {
                self.image = img
                self.size = img.size
                self.cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
                self.isFullLoaded = true
            }
            return
        }
        
        // 1. 크기 메타데이터 고속 추출 (디코딩 없이 0.1ms 소요)
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
           let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            self.size = CGSize(width: width, height: height)
        }
        
        // 2. 저해상도 썸네일/프록시 생성 (2~3ms 초고속 서브샘플링)
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1000,
            kCGImageSourceShouldCacheImmediately: true
        ]
        self.thumbnailCGImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary)
        
        if self.size == .zero, let thumb = self.thumbnailCGImage {
            self.size = CGSize(width: thumb.width, height: thumb.height)
        }
        
        if loadFullImmediately {
            loadFullResolution(from: source)
        }
    }
    
    mutating func loadFullResolution(from existingSource: CGImageSource? = nil) {
        guard !isFullLoaded, let data = imageData else { return }
        let source = existingSource ?? CGImageSourceCreateWithData(data as CFData, nil)
        guard let source = source else { return }
        
        let fullOptions: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]
        if let fullCG = CGImageSourceCreateImageAtIndex(source, 0, fullOptions as CFDictionary) {
            self.cgImage = fullCG
            self.image = NSImage(cgImage: fullCG, size: self.size)
            self.isFullLoaded = true
        }
    }
    
    static func == (lhs: ComicPage, rhs: ComicPage) -> Bool {
        lhs.id == rhs.id && lhs.index == rhs.index && lhs.entryName == rhs.entryName && lhs.isFullLoaded == rhs.isFullLoaded
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(index)
        hasher.combine(entryName)
        hasher.combine(isFullLoaded)
    }
}
