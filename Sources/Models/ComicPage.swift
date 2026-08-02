import Foundation
import AppKit

/// 개별 만화 페이지 정보를 담는 모델
struct ComicPage: Identifiable, Hashable {
    let id: UUID = UUID()
    let index: Int
    let entryName: String
    var imageData: Data?
    
    // NSImage로 변환하여 반환
    var image: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }
}
