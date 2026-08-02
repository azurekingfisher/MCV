# macOS 네이티브 만화책 뷰어 개발 명세서 (AI 어시스턴트용)

이 문서는 macOS 환경에서 최상의 속도와 안정성을 제공하는 만화책 뷰어 앱을 개발하기 위한 프로젝트 명세서이자 AI 코딩 어시스턴트(안티그래비티, Cursor 등)에게 제공할 가이드라인입니다.

## 1. 프로젝트 개요
- **타겟 OS:** macOS 13 (Ventura) 이상 (webp, avif 네이티브 지원 활용)
- **프레임워크:** Swift & SwiftUI (macOS 네이티브)
- **아키텍처 패턴:** MVVM (Model - View - ViewModel)
- **핵심 목표:** 
  - 압축 파일(Zip) 스트리밍 추출을 통한 **극강의 속도와 낮은 메모리 점유율**
  - 콘텐츠 몰입을 방해하지 않는 **무채색 기반의 다크 모드 UI**

## 2. 주요 기능 및 요구사항

### 2.1 책장 모드 (Library)
- 지정된 폴더 내의 Zip 파일들을 스캔하여 첫 번째 이미지를 썸네일로 표시합니다.
- **썸네일 캐싱:** 
  - 듀얼 32인치 모니터와 같은 고해상도 작업 환경에서 창을 크게 띄워놓고 사용할 때 썸네일이 깨지지 않고 원활하게 표시되도록, 캐시 용량은 기본 100MB 이상으로 넉넉하게 설정합니다.
  - 중복 방지 및 업데이트 감지를 위해 썸네일 파일명은 **'원본 파일의 절대 경로 + 마지막 수정 시간(Modified Date)'을 조합한 해시값**으로 저장합니다.
  - 용량 관리는 복잡한 UI 대신 macOS의 `Caches` 디렉토리를 활용하여 OS가 관리하도록 위임합니다(또는 백그라운드 LRU 적용).
- 썸네일 클릭 시 뷰어 모드로 진입합니다. UI 설정(썸네일+제목 / 썸네일만 / 제목만) 변경이 가능해야 합니다.

### 2.2 뷰어 모드 (Viewer)
- **파일 포맷:** Zip 압축파일 내부의 jpg, png, webp, avif 파일을 지원합니다.
- **스트리밍 디코딩:** 압축파일을 풀지 않고 `ZIPFoundation`을 이용해 목차만 읽은 뒤, 필요한 페이지의 데이터만 메모리에 올려 렌더링합니다. (현재 페이지 기준 앞뒤 2페이지만 캐싱하여 메모리 최적화)
- **보기 모드:**
  - 한 장 보기 / 두 장 보기 (양면 보기)
  - 왼쪽으로 읽기 / 오른쪽으로 읽기 (방향에 따라 페이지 전환 키 매핑 변경)
  - 두 장 보기 시 좌우 위치 반전 기능
- **스프레드(가로형) 이미지 예외 처리:** 양면 보기 모드 중 가로 길이가 세로보다 긴 이미지가 감지되면, 자동으로 한 장 꽉 찬 화면으로 보여주어 작가의 의도를 살립니다.
- **네비게이션 및 UX:**
  - 하단 네비게이션 바: 영상 편집기의 타임라인과 유사한 형태의 스크러버(Scrubber)를 배치하여, 마우스 드래그로 빠르게 페이지를 탐색할 수 있게 합니다. 책장으로 돌아가는 버튼을 포함합니다.
  - 권 이동 오버레이: 첫 장/마지막 장에서 이전/다음 권으로 넘어갈 때, 방해되는 팝업(Alert) 대신 화면 중앙에 반투명한 안내 문구를 띄우고 자연스럽게 전환합니다.
  - 트랙패드 제스처: 두 손가락 스와이프로 페이지 전환, 핀치 투 줌을 지원합니다.

## 3. 앱 아키텍처 (MVVM 구조)

- **Models:** 
  - `ComicBook`: 파일 경로, 이름, 해시값, 총 페이지 수 등
  - `ComicPage`: 페이지 인덱스 및 이미지 데이터 상태
- **Services:**
  - `ZipArchiveService`: `ZIPFoundation`을 이용한 목차 스캔 및 메모리 내 직접 데이터 추출 (스트리밍)
  - `ThumbnailCacheService`: 해시 기반 썸네일 로컬 저장 및 불러오기
- **ViewModels:**
  - `LibraryViewModel`: 폴더 스캔, 파일 목록화, 썸네일 로드 상태 관리
  - `ViewerViewModel`: 현재 페이지 위치, 보기 설정(단면/양면, 읽는 방향), 스프레드 감지, 앞뒤 페이지 메모리 캐싱 로직 관리
- **Views:**
  - `LibraryView`: LazyVGrid 기반의 책장 UI
  - `ViewerView`: 메인 이미지 렌더러, 트랙패드 제스처 처리, 하단 타임라인 네비게이션 바

## 4. 단계별 개발 지시 프롬프트 (AI 입력용)

1. **초기 세팅:** "macOS 13 이상 타겟, SwiftUI 만화책 뷰어 앱을 만들 거야. MVVM 패턴으로 Models, ViewModels, Views, Services 폴더 구조를 만들고 빈 파일들로 뼈대를 잡아줘."
2. **서비스 구현:** "Services 폴더에 `ZipArchiveService`(ZIPFoundation 활용, 부분 추출)와 `ThumbnailCacheService`(경로+수정시간 해시 기반, OS Caches 폴더 활용)를 프로토콜을 사용해 구현해 줘. 에러 처리를 꼼꼼히 해줘."
3. **책장 뷰어:** "`LibraryViewModel`과 `LibraryView`를 구현해. 폴더 스캔 후 썸네일과 제목을 LazyVGrid로 무채색 배경 위에 띄워줘. 상태에 따라 썸네일만/제목만 보이게 하는 기능도 넣어줘."
4. **뷰어 로직:** "`ViewerViewModel`을 만들어 줘. 단면/양면 상태, 읽는 방향, 양면 반전 기능을 넣고, 메모리 관리를 위해 현재 위치 기준 앞뒤 2페이지만 캐싱하는 로직을 작성해. 스프레드 컷 감지 기능도 포함해 줘."
5. **뷰어 UI:** "`ViewerView`와 하단 바를 구현해. 완전 어두운 배경에 트랙패드 스와이프 제스처를 넣고, 하단에는 타임라인식 스크러버와 책장 복귀 버튼을 만들어 줘. 이전/다음 권 이동 시 반투명 오버레이를 띄워 줘."

## 5. 핵심 참고 코드 (ZipArchiveService)
- 부분 추출(스트리밍) 기능을 구현할 때 아래의 `ZIPFoundation` 활용 로직을 참고하여 구현하도록 지시하세요.
```swift
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
```
