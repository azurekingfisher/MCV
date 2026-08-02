import Foundation
import ZIPFoundation

enum ZipArchiveError: Error {
    case archiveCreationFailed
    case entryNotFound
    case unsupportedFormat
}

protocol ZipArchiveServiceProtocol {
    func getPageEntries(from archiveURL: URL) throws -> [String]
    func extractImageData(from archiveURL: URL, entryName: String) throws -> Data
}

class ZipArchiveService: ZipArchiveServiceProtocol {
    
    // 지원하는 이미지 확장자 목록
    private let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "avif"]
    
    /// 압축 파일 내의 이미지 목차(Entry name)를 정렬하여 반환
    func getPageEntries(from archiveURL: URL) throws -> [String] {
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ZipArchiveError.archiveCreationFailed
        }
        
        var entries: [String] = []
        for entry in archive {
            let pathExtension = (entry.path as NSString).pathExtension.lowercased()
            if entry.type == .file && supportedExtensions.contains(pathExtension) {
                // 맥OS 시스템 파일 등 불필요한 파일 제외
                if !entry.path.contains("__MACOSX") && !entry.path.hasPrefix(".") {
                    entries.append(entry.path)
                }
            }
        }
        
        // 자연스럽게 이름순으로 정렬 (ex: 1.jpg, 2.jpg, 10.jpg)
        return entries.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    
    /// 특정 엔트리의 데이터를 메모리에 바로 압축 해제(스트리밍)하여 반환
    func extractImageData(from archiveURL: URL, entryName: String) throws -> Data {
        guard let archive = Archive(url: archiveURL, accessMode: .read),
              let entry = archive[entryName] else {
            throw ZipArchiveError.entryNotFound
        }
        
        var extractedData = Data()
        _ = try archive.extract(entry) { data in
            extractedData.append(data) // 디스크 쓰기 없이 메모리로 바로 누적
        }
        return extractedData
    }
}
