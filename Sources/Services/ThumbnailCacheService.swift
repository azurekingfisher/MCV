import Foundation
import AppKit

protocol ThumbnailCacheServiceProtocol {
    func getThumbnail(for id: String) -> NSImage?
    func saveThumbnail(image: NSImage, for id: String)
    func cleanCacheIfNeeded()
}

class ThumbnailCacheService: ThumbnailCacheServiceProtocol {
    
    private let cacheDirectory: URL
    private let maxCacheSizeBytes: Int = 300 * 1024 * 1024 // 300 MB
    
    init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = urls[0].appendingPathComponent("com.MCV.ThumbnailCache")
        
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.cacheDirectory = cacheDir
        
        // 앱 시작 시 백그라운드에서 오래된 캐시 정리
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.cleanCacheIfNeeded()
        }
    }
    
    func getThumbnail(for id: String) -> NSImage? {
        var fileURL = cacheDirectory.appendingPathComponent(id)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        
        // 읽을 때 접근 시간 업데이트 (LRU 정렬용)
        var resourceValues = URLResourceValues()
        resourceValues.contentAccessDate = Date()
        try? fileURL.setResourceValues(resourceValues)
        
        return NSImage(data: data)
    }
    
    func saveThumbnail(image: NSImage, for id: String) {
        let fileURL = cacheDirectory.appendingPathComponent(id)
        
        // 1. 썸네일 해상도 축소 (최대 긴 쪽 400px 제한)
        let resizedImage = resizeForThumbnail(image: image, maxDimension: 400)
        
        // 2. 썸네일을 Jpeg로 저장 (압축 및 품질 조절 0.7)
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return
        }
        
        try? jpegData.write(to: fileURL)
    }
    
    private func resizeForThumbnail(image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        
        let ratio = maxDimension / max(size.width, size.height)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
    
    func cleanCacheIfNeeded() {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentAccessDateKey]
        
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: resourceKeys, options: .skipsHiddenFiles) else { return }
        
        var files: [(url: URL, size: Int, accessDate: Date)] = []
        var totalSize: Int = 0
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let fileSize = resourceValues.fileSize else { continue }
            
            // 만약 접근 시간이 없으면 생성 시간을 대체로 사용
            let accessDate = resourceValues.contentAccessDate ?? Date.distantPast
            
            files.append((url: fileURL, size: fileSize, accessDate: accessDate))
            totalSize += fileSize
        }
        
        // 캐시 용량이 제한(300MB)을 초과한 경우
        if totalSize > maxCacheSizeBytes {
            // 접근 날짜 기준 오름차순(가장 오래된 파일이 0번 인덱스) 정렬
            files.sort { $0.accessDate < $1.accessDate }
            
            // 잦은 정리를 막기 위해 최대 용량의 70% (약 210MB)까지 비움
            let targetSize = Int(Double(maxCacheSizeBytes) * 0.7)
            
            for file in files {
                if totalSize <= targetSize { break }
                try? fileManager.removeItem(at: file.url)
                totalSize -= file.size
            }
            print("썸네일 캐시 정리 완료: 남은 용량 \(totalSize / (1024 * 1024))MB")
        }
    }
}
