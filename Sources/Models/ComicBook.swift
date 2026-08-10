import Foundation

enum ItemType {
    case upFolder
    case folder
    case book
}

/// 만화책 정보를 담는 모델
struct ComicBook: Identifiable, Hashable {
    let id: String // 절대 경로와 마지막 수정 시간을 조합한 해시값
    let url: URL
    let title: String
    var totalPages: Int
    var isThumbnailLoaded: Bool = false
    var type: ItemType
    
    init(url: URL, type: ItemType = .book) {
        self.url = url
        self.type = type
        
        if type == .upFolder {
            self.title = "상위 폴더로"
        } else {
            self.title = url.deletingPathExtension().lastPathComponent
        }
        
        // 고유 ID(해시) 생성: 경로 + 수정시간
        let path = url.path
        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        self.id = "\(path)_\(modDate.timeIntervalSince1970)".hashString()
        self.totalPages = 0
    }
}

extension String {
    /// 간단한 해시값 생성 헬퍼
    func hashString() -> String {
        return String(format: "%016llx", UInt64(bitPattern: Int64(self.hashValue)))
    }
}
