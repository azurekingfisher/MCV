import Foundation
import AppKit

protocol ThumbnailCacheServiceProtocol {
    func getThumbnail(for id: String) -> NSImage?
    func saveThumbnail(image: NSImage, for id: String)
}

class ThumbnailCacheService: ThumbnailCacheServiceProtocol {
    
    private let cacheDirectory: URL
    
    init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = urls[0].appendingPathComponent("com.MCV.ThumbnailCache")
        
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.cacheDirectory = cacheDir
    }
    
    func getThumbnail(for id: String) -> NSImage? {
        let fileURL = cacheDirectory.appendingPathComponent(id)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return NSImage(data: data)
    }
    
    func saveThumbnail(image: NSImage, for id: String) {
        let fileURL = cacheDirectory.appendingPathComponent(id)
        
        // 썸네일을 Jpeg 혹은 PNG로 저장 (압축 및 품질 조절)
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return
        }
        
        try? jpegData.write(to: fileURL)
    }
}
