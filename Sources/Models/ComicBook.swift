import Foundation
import CryptoKit

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
    let creationDate: Date
    
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
        self.creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
    }
}

extension String {
    /// 앱 재시작 시에도 변하지 않는 고정 길이(64자) SHA256 해시 생성 헬퍼
    func hashString() -> String {
        let data = Data(self.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
