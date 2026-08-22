#!/bin/bash
set -e

echo "=== MCV 1.5.5 .app 번들 생성 시작 ==="

# 1. 릴리즈 빌드
swift build -c release

# 2. 경로 설정
APP_NAME="MCV"
VERSION="1.5.5"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# 3. 디렉터리 구조 생성
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 4. 실행 파일 복사
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 5. SPM 번들 리소스 복사 (있는 경우)
if [ -d "${BUILD_DIR}/MCV_MCV.bundle" ]; then
    cp -R "${BUILD_DIR}/MCV_MCV.bundle" "${RESOURCES_DIR}/"
fi
if [ -f "mcv_icon.png" ]; then
    cp "mcv_icon.png" "${RESOURCES_DIR}/mcv_icon.png"
fi

# 6. 아이콘 (.icns) 생성
ICONSET_DIR="AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"
sips -z 16 16     mcv_icon.png --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32     mcv_icon.png --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32     mcv_icon.png --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64     mcv_icon.png --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128   mcv_icon.png --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256   mcv_icon.png --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256   mcv_icon.png --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512   mcv_icon.png --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512   mcv_icon.png --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 mcv_icon.png --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null 2>&1

iconutil -c icns "${ICONSET_DIR}" --out "${RESOURCES_DIR}/AppIcon.icns"
rm -rf "${ICONSET_DIR}"

# 7. Info.plist 생성
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MCV</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.igyeongseob.MCV</string>
    <key>CFBundleName</key>
    <string>MCV</string>
    <key>CFBundleDisplayName</key>
    <string>MCV</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.5.5</string>
    <key>CFBundleVersion</key>
    <string>1.5.5</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. All rights reserved.</string>
</dict>
</plist>
EOF

echo "=== MCV.app 번들 생성 완료! ==="
