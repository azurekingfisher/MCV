import Foundation
import AppKit

/// 개별 만화 페이지 정보를 담는 모델
struct ComicPage: Identifiable, Hashable {
    let id: UUID = UUID()
    let index: Int
    let entryName: String
    var imageData: Data?
    
    // 1회만 디코딩하여 캐싱 보관 (고해상도 이미지 반복 디코딩 오버헤드 0으로 제거)
    var image: NSImage?
    var cgImage: CGImage?
    var size: CGSize = .zero
    
    init(index: Int, entryName: String, imageData: Data?) {
        self.index = index
        self.entryName = entryName
        self.imageData = imageData
        
        if let data = imageData, let img = NSImage(data: data) {
            self.image = img
            self.size = img.size
            if let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                self.cgImage = cg
            }
        }
    }
    
    static func == (lhs: ComicPage, rhs: ComicPage) -> Bool {
        lhs.id == rhs.id && lhs.index == rhs.index && lhs.entryName == rhs.entryName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(index)
        hasher.combine(entryName)
    }
}
