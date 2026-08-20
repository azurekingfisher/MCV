# Implementation Spec: Liquid Glass Speech Bubble & Overlay UI

## 1. Apple HIG Core Principles (Bubble Overlay)
* **Clear Variant over Rich Backgrounds**: 시각적으로 복잡한 이미지(만화/웹툰 컷) 위에 올라가는 요소는 배경을 과도하게 가리지 않도록 고투명도의 `Clear Liquid Glass` 스타일을 적용합니다.
* **Content Hierarchy & Vibrancy**: 텍스트 레이어는 글래스 재질 위에 위치해야 하며, 배경 대비 최소 4.5:1(WCAG AA) 이상의 명도 대비를 유지하도록 시스템 Vibrant Color 또는 서브 섀도우를 적용합니다.
* **Specular Edge Refraction**: 가장자리에 미세한 빛 굴절 효과(1px 반투명 보더 및 이너 글로우)를 부여해 유리 재질감과 시각적 분리감을 형성합니다.
* **Accessibility Fallback**: 시스템의 '투명도 줄이기(Reduce Transparency)' 설정 활성화 시 블러 효과를 끄고 불투명/단색 배경(Fallback Material)으로 전환합니다.

---

## 2. Component Design Tokens

| Property | Standard Value | Reduced Transparency Fallback |
| :--- | :--- | :--- |
| **Material Base** | Ultra-Thin / Dynamic Clear Glass | Solid System Background (Opacity 95%) |
| **Backdrop Blur** | `20px` ~ `30px` (macOS/iOS 기준) | `0px` (None) |
| **Specular Border** | `1px solid rgba(255, 255, 255, 0.25)` | `1px solid rgba(0, 0, 0, 0.15)` |
| **Inner Glow / Lift** | `inset 0 1px 1px rgba(255, 255, 255, 0.3)` | None |
| **Drop Shadow** | `0 8px 24px rgba(0, 0, 0, 0.12)` | `0 4px 12px rgba(0, 0, 0, 0.08)` |
| **Typography** | Primary Label with subtle text shadow | Primary Solid Color |

---

## 3. Implementation Code

### Option A: SwiftUI (Native macOS / iOS)
```swift
import SwiftUI

struct LiquidGlassBubbleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.windowBackgroundColor).opacity(0.95))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        // macOS Tahoe / iOS 26+ Liquid Glass Effect
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                }
            }
    }
}

extension View {
    func liquidGlassBubble() -> some View {
        self.modifier(LiquidGlassBubbleModifier())
    }
}
