import SwiftUI

struct ReleaseNotesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("MCV 개선 사항")
                    .font(.largeTitle)
                    .bold()
                
                // v1.5.2
                versionSection(
                    version: "v1.5.2",
                    date: "2026.08.21",
                    items: [
                        "뷰어 모드 하단바 및 오버레이에 macOS 리퀴드 글래스(Liquid Glass) 디자인 스타일 적용 (울트라 씬 블러, 빛 굴절 테두리, 입체 섀도우, 접근성 투명도 폴백)",
                        "확대 상태에서 페이지의 가로 폭이 창 폭 이내인 경우 좌우 방향키(←, →)로 자연스러운 페이지 이동(넘김) 지원"
                    ]
                )
                
                Divider()
                
                // v1.5.1
                versionSection(
                    version: "v1.5.1",
                    date: "2026.08.20",
                    items: [
                        "책장 모드 최신순 정렬 시, 폴더 자체 생성 날짜 대신 '폴더 내 가장 최신 파일의 생성/수정 날짜'를 기준으로 정렬하도록 개선"
                    ]
                )
                
                Divider()
                
                // v1.5.0
                versionSection(
                    version: "v1.5.0",
                    date: "2026.08.18",
                    items: [
                        "와이드(스프레드) 겉표지 스캔본을 위한 썸네일 표시 영역 지정 & 토글 기능 추가 (현재 방식/왼쪽/오른쪽/가로 꽉 차게)",
                        "확대(Zoom) 상태에서 패닝 시 이미지 끝에 딱 맞추는 경계 제한(Clamping) 구현 및 검은 여백 노출 방지",
                        "확대 및 가로 맞춤 모드에서 다음 페이지 이동 시 '최상단', 이전 페이지 이동 시 '최하단(또는 최상단)' 스마트 위치 정렬",
                        "하단바 톱니바퀴 메뉴에 '이전 페이지 이동 시 위치(최하단/최상단)' 설정 옵션 추가",
                        "스마트 줌 확대 비율 메뉴를 마우스 호버 즉시 펼쳐지는 다이렉트 서브메뉴 방식으로 UI 최적화",
                        "가로로 꽉 차게 보기(H 키) 단축키를 단방향 지정으로 안정화"
                    ]
                )
                
                Divider()
                
                // v1.4.0
                versionSection(
                    version: "v1.4.0",
                    date: "2026.08.17",
                    items: [
                        "책장 모드 전용 Cmd + O 폴더 열기 단축키 및 상단 File 메뉴바 연동 (뷰어 모드 격리)",
                        "도움말 창(Help) 반응형 창 크기 조절 지원 (창 크기에 맞춰 텍스트 영역 유연 확장)",
                        "상단 Help 메뉴에 버전별 '개선 사항' 전용 윈도우 추가",
                        "단축키 중복 매핑 정리 및 도움말 설명 문구 최적화"
                    ]
                )
                
                Divider()
                
                // v1.3.5
                versionSection(
                    version: "v1.3.5",
                    date: "2026.08.17",
                    items: [
                        "트랙패드 두 손가락 1페이지 스와이프 넘김 및 쓸림 애니메이션 추가",
                        "사파리 스타일 두 손가락 더블 탭 및 키보드 슬래시(/) 스마트 줌 토글 구현",
                        "뷰어 하단 톱니바퀴 설정 메뉴에 스마트 줌 배율(150%, 200%, 300%) 선택 옵션 추가",
                        "가로 맞춤 보기(H 키 토글) 및 흑백 만화 맞춤 중간 회색(Medium Gray) 오버레이 스크롤바 적용",
                        "창 숨기기(Cmd + H) 토글 기능 구현 및 단축키 간섭 해결",
                        "Help 메뉴 팝업 렌더링 정상화 및 MCV 도움말 창 추가"
                    ]
                )
                
                Divider()
                
                // v1.3.0
                versionSection(
                    version: "v1.3.0",
                    date: "2026.08.17",
                    items: [
                        "책장 모드 썸네일 클릭 시 인접한 책이 잘못 선택되던 히트 테스팅 및 그리드 정렬 버그 수정"
                    ]
                )
                
                Divider()
                
                // v1.2.4
                versionSection(
                    version: "v1.2.4",
                    date: "2026.08.17",
                    items: [
                        "흑백 만화 전용 자동 대비 개선(Auto Contrast) 모드 추가",
                        "책장 모드에서 한글 입력기 상태일 때 전체화면 전환(F 키)이 동작하지 않던 오류 수정"
                    ]
                )
                
                Divider()
                
                // v1.2.0 ~ v1.2.3
                versionSection(
                    version: "v1.2.0 ~ v1.2.3",
                    date: "2026.08.11",
                    items: [
                        "Esc 키 입력 시 전체화면 상태를 유지한 채 책장으로 복귀하도록 개선",
                        "책장 만화책 목록 Finder 방식 자연어 제목순(가나다/알파벳/숫자) 및 최신순 정렬 기능 추가",
                        "창모드 타이틀바 클리핑 및 썸네일 캐시 경로 안정화"
                    ]
                )
                
                Divider()
                
                // v1.1.0 ~ v1.1.9
                versionSection(
                    version: "v1.1.0 ~ v1.1.9",
                    date: "2026.08.03",
                    items: [
                        "초고속 GPU 가속 기반 이미지 선명도(샤픈 필터) 조절 옵션(끄기/약하게/보통/강하게) 구현",
                        "책장 모드 키보드 방향키 이동, 파란색 테두리 하이라이트 및 엔터키 뷰어 진입 지원",
                        "썸네일 300MB 용량 제한 LRU 디스크 캐시 자동 정리 및 폴더 탐색 구조 도입",
                        "가로 꽉 차게 보기 모드 페이지 전환 시 상단 스크롤 위치 자동 리셋"
                    ]
                )
                
                Divider()
                
                // v1.0.0
                versionSection(
                    version: "v1.0.0",
                    date: "2026.08.02",
                    items: [
                        "macOS 전용 고성능 만화책 뷰어(MCV) 최초 릴리즈",
                        "ZIP / CBZ 무압축 해제 스트리밍 읽기 및 초고화질 Lanczos 보간 렌더링",
                        "단면 / 양면 보기 및 키보드 단축키 지원"
                    ]
                )
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 500, minHeight: 500)
    }
    
    @ViewBuilder
    private func versionSection(version: String, date: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(version)
                    .font(.title2)
                    .bold()
                Text(date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(item)
                            .lineSpacing(4)
                    }
                }
            }
        }
    }
}
