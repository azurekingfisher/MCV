import SwiftUI

struct SettingsView: View {
    @State private var limitValueText: String = ""
    @State private var limitUnit: String = "MB"
    @State private var currentCacheSize: Int = 0
    @State private var isCalculatingSize: Bool = false
    @State private var showClearAlert: Bool = false
    @State private var toastMessage: String? = nil
    
    private var isInputEmpty: Bool {
        limitValueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var parsedValue: Int? {
        Int(limitValueText)
    }
    
    private var isValidInput: Bool {
        guard let val = parsedValue, val > 0 else { return false }
        return true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("설정")
                .font(.title2)
                .bold()
            
            // 썸네일 캐시 관리 그룹
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. 현재 캐시 사용량 및 캐시 즉시 비우기
                    HStack(spacing: 12) {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("현재 캐시 사용량")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 6) {
                                if isCalculatingSize {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("계산 중...")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(formattedCacheSize(currentCacheSize))
                                        .font(.headline)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            showClearAlert = true
                        } label: {
                            Label("캐시 즉시 비우기", systemImage: "trash")
                        }
                        .controlSize(.regular)
                    }
                    
                    Divider()
                    
                    // 2. 최대 캐시 용량 설정 (숫자 입력 + MB/GB 단위 선택 + 적용)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18))
                                .foregroundColor(.accentColor)
                                .frame(width: 28)
                            
                            Text("최대 캐시 용량")
                                .font(.headline)
                            
                            Spacer()
                            
                            // 숫자만 입력 가능한 텍스트 필드
                            TextField("용량 입력", text: $limitValueText)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: limitValueText) { newValue in
                                    // 숫자만 엄격하게 필터링 (숫자가 아닌 문자는 즉시 제거)
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue {
                                        limitValueText = filtered
                                    }
                                }
                                .onSubmit {
                                    if isValidInput {
                                        applySettings()
                                    }
                                }
                            
                            // MB / GB 단위 선택 세그먼트
                            Picker("단위", selection: $limitUnit) {
                                Text("MB").tag("MB")
                                Text("GB").tag("GB")
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 100)
                            
                            // 적용 버튼 (숫자가 입력되지 않으면 비활성화)
                            Button("적용") {
                                applySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!isValidInput)
                        }
                        
                        // 유효성 검사 안내 문구
                        if isInputEmpty {
                            HStack {
                                Spacer()
                                Text("숫자를 입력해야 설정을 완료할 수 있습니다.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        } else if let val = parsedValue, val == 0 {
                            HStack {
                                Spacer()
                                Text("1 이상의 숫자를 입력해야 설정을 완료할 수 있습니다.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 3. 안내 설명문
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                        
                        Text("설정된 최대 용량을 초과하면 가장 오래된 썸네일부터 자동으로 삭제되어 여유 공간을 확보합니다. (기본값: 400 MB)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
            } label: {
                Label("썸네일 캐시 관리", systemImage: "photo.stack")
                    .font(.headline)
            }
            
            // 토스트 / 알림 메시지
            if let msg = toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(msg)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .shadow(radius: 3)
                .transition(.opacity)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            loadCurrentSettings()
            refreshCacheSize()
        }
        .alert("썸네일 캐시 비우기", isPresented: $showClearAlert) {
            Button("캐시 비우기", role: .destructive) {
                clearCache()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("저장된 모든 썸네일 캐시를 삭제하시겠습니까?\n책장을 열면 썸네일이 필요에 따라 다시 생성됩니다.")
        }
    }
    
    private func loadCurrentSettings() {
        let currentVal = ThumbnailCacheService.shared.currentCacheLimitValue
        let currentUnit = ThumbnailCacheService.shared.currentCacheLimitUnit
        limitValueText = "\(currentVal)"
        limitUnit = currentUnit
    }
    
    private func refreshCacheSize() {
        isCalculatingSize = true
        DispatchQueue.global(qos: .userInitiated).async {
            let size = ThumbnailCacheService.shared.getCurrentCacheSizeBytes()
            DispatchQueue.main.async {
                self.currentCacheSize = size
                self.isCalculatingSize = false
            }
        }
    }
    
    private func applySettings() {
        guard isValidInput, let val = parsedValue else { return }
        ThumbnailCacheService.shared.updateCacheLimit(value: val, unit: limitUnit)
        showToast("설정이 저장되었습니다. (최대: \(val) \(limitUnit))")
        
        // 캐시 정리 후 용량 재계산
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            refreshCacheSize()
        }
    }
    
    private func clearCache() {
        ThumbnailCacheService.shared.clearAllCache()
        LibraryViewModel.current?.reloadThumbnails()
        refreshCacheSize()
        showToast("썸네일 캐시를 모두 비웠습니다.")
    }
    
    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
    
    private func formattedCacheSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
