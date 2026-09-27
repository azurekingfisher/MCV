---
name: mcv-release
description: >-
  Use this skill whenever the user asks to bump the MCV application version, release a new version, update Help release notes, build the release bundle, create a release zip archive, commit/push to GitHub, or prepare GitHub release notes.
---

# MCV Release Workflow Skill

This skill automates and guides the standard release procedure for the **MCV (macOS Comic Viewer)** application.

## Release Checklist & Execution Steps

When the user requests releasing a new version (e.g. `vX.Y.Z`), execute the following steps in order:

### 1. Version Bump in Configuration & Code
Update the version string across the following files:

1. **`Sources/MCVApp.swift`**
   - In `ViewerCommands`, update the About panel options:
     - `.applicationVersion: "X.Y.Z"`
     - `.version: "X.Y.Z"`
     - `credits: NSAttributedString(string: "macOS 만화책 뷰어 vX.Y.Z", ...)`

2. **`create_app.sh`**
   - Update the header echo: `echo "=== MCV X.Y.Z .app 번들 생성 시작 ==="`
   - Update variable: `VERSION="X.Y.Z"`
   - Update `Info.plist` template inside the script:
     - `CFBundleShortVersionString` -> `X.Y.Z`
     - `CFBundleVersion` -> `X.Y.Z`

### 2. Update In-App Release Notes
Update **`Sources/Views/ReleaseNotesView.swift`**:
- Insert a new `versionSection` at the top of the version list (above the previous version):
  ```swift
  // vX.Y.Z
  versionSection(
      version: "vX.Y.Z",
      date: "YYYY.MM.DD", // Current date
      items: [
          "Brief description of change 1",
          "Brief description of change 2"
      ]
  )

  Divider()
  ```

### 3. Build Release `.app` Bundle
Run the build script in terminal (requires `BypassSandbox: true`):
```bash
bash create_app.sh
```
Ensure build exits with code 0 and `MCV.app` bundle is generated in the workspace root.

### 4. Create Release Zip Archive
Compress `MCV.app` using symlink-preserving and macOS metadata options:
```bash
rm -f MCV_vX.Y.Z.zip && zip -r -y -X MCV_vX.Y.Z.zip MCV.app
```
Verify the zip archive integrity:
```bash
unzip -t MCV_vX.Y.Z.zip
```

### 5. Git Commit & Push to GitHub
Stage all changed files, commit with clean message, and push:
```bash
git add .
git commit -m "Release vX.Y.Z: <Core Feature / Fix Summary>" -m "<Detailed bullet points>"
git push origin main
```

### 6. Prepare Concise GitHub Release Notes
Provide the user with a concise, ready-to-copy release notes snippet for the [GitHub Releases](https://github.com/azurekingfisher/MCV/releases/new) page:
```markdown
## MCV vX.Y.Z

### 🚀 주요 변경 사항
- **기능/수정 제목**: 간결한 핵심 요약 설명

---

### ⚠️ macOS 최초 실행 보안 경고 해결 방법
비영리 오픈소스 특성상 개발자 서명이 포함되어 있지 않습니다. 최초 실행 시 아래 방법 중 하나로 실행해 주세요:
- **시스템 설정에서 열기**: 실행 후 차단 대화상자가 뜨면 ** ➔ 시스템 설정 ➔ 개인정보 보호 및 보안 ➔ 보안** 섹션에서 **"그래도 열기"** 클릭
- 또는 터미널에서 격리 속성 해제: `xattr -cr /Applications/MCV.app`
```
