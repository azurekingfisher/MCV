import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("MCV 도움말")
                    .font(.largeTitle)
                    .bold()
                
                Group {
                    Text("단축키 안내").font(.title3).bold()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• 방향키 (←, →): 이전/다음 페이지 넘기기")
                        Text("• 방향키 (↑, ↓): 확대/가로맞춤 시 상하 스크롤")
                        Text("• Space / Shift+Space: 화면 단위로 아래/위로 스크롤 (끝에서 페이지 넘김)")
                        Text("• 마우스 클릭: 화면 좌/우 클릭으로 이전/다음 페이지 넘기기")
                        Text("• F: 전체화면 전환")
                        Text("• V: 세로 맞춤 보기")
                        Text("• H: 가로 맞춤 보기")
                        Text("• [ / ]: 이전 권 / 다음 권으로 이동")
                        Text("• / (슬래시): 스마트 줌 (설정된 배율로 토글)")
                        Text("• -, =, 0: 축소, 확대, 100% 원래 크기")
                    }
                }
                
                Divider()
                
                Group {
                    Text("트랙패드 조작법").font(.title3).bold()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• 두 손가락 스와이프: 좌우로 화면을 밀어서 이전/다음 페이지로 이동 (애니메이션 지원)")
                        Text("• 두 손가락 스크롤: 화면이 확대되었을 때 상하좌우 부드러운 위치 탐색")
                        Text("• 핀치 투 줌: 두 손가락을 모으거나 벌려서 자유롭게 확대/축소")
                        Text("• 두 손가락 더블 탭: 설정된 배율(기본 200%)로 즉시 확대 및 축소 토글")
                    }
                }
                
                Divider()
                
                Group {
                    Text("메뉴 사용법").font(.title3).bold()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• 파일 열기: 상단 File 메뉴 또는 단축키(Cmd + O)를 통해 만화책 파일(zip, cbz) 또는 폴더를 엽니다.")
                        Text("• 환경 설정: 뷰어 하단 톱니바퀴 메뉴를 눌러 스마트 줌 배율 등 환경을 설정합니다.")
                        Text("• 창 숨기기: Cmd + H를 누르면 앱이 활성화된 상태로 창만 숨겨집니다. 다시 누르면 나타납니다.")
                        Text("• 도움말: Help 메뉴를 통해 언제든 이 도움말을 다시 엽니다.")
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 450, minHeight: 450)
    }
}
