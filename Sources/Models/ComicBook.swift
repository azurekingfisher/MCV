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
        if type == .folder {
            self.creationDate = ComicBook.getLatestDate(for: url)
        } else {
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let cDate = values?.creationDate ?? Date.distantPast
            let mDate = values?.contentModificationDate ?? Date.distantPast
            let maxDate = max(cDate, mDate)
            self.creationDate = (maxDate != Date.distantPast) ? maxDate : Date()
        }
    }
    
    /// 폴더 내의 가장 최신 파일 생성/수정 날짜를 검색 (없으면 폴더 자체 날짜 반환)
    static func getLatestDate(for folderURL: URL) -> Date {
        let fileManager = FileManager.default
        let folderValues = try? folderURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        var latestDate = max(
            folderValues?.creationDate ?? Date.distantPast,
            folderValues?.contentModificationDate ?? Date.distantPast
        )
        if latestDate == Date.distantPast {
            latestDate = Date()
        }
        
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return latestDate
        }
        
        var count = 0
        let maxFilesToCheck = 1000
        
        for case let fileURL as URL in enumerator {
            count += 1
            if count > maxFilesToCheck { break }
            
            if let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) {
                if let cDate = values.creationDate, cDate > latestDate {
                    latestDate = cDate
                }
                if let mDate = values.contentModificationDate, mDate > latestDate {
                    latestDate = mDate
                }
            }
        }
        
        return latestDate
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
