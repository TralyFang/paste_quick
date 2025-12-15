#!/bin/bash

# 快速创建 DMG 的脚本（需要先运行 package.sh）

set -e

APP_NAME="PasteQuick"
VERSION="1.0"
RELEASE_DIR="release"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

if [ ! -d "${RELEASE_DIR}/${APP_NAME}.app" ]; then
    echo "❌ 错误：找不到应用包，请先运行 ./package.sh"
    exit 1
fi

echo "🎨 创建 DMG 磁盘镜像..."

# 创建临时目录用于 DMG
TEMP_DMG_DIR="temp_dmg"
rm -rf "${TEMP_DMG_DIR}"
mkdir -p "${TEMP_DMG_DIR}"

# 复制应用和创建快捷方式
cp -R "${RELEASE_DIR}/${APP_NAME}.app" "${TEMP_DMG_DIR}/"
ln -s /Applications "${TEMP_DMG_DIR}/Applications"

# 创建 DMG
if hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${TEMP_DMG_DIR}" \
    -ov -format UDZO \
    "${RELEASE_DIR}/${DMG_NAME}" 2>/dev/null; then
    echo "✅ DMG 创建成功: ${RELEASE_DIR}/${DMG_NAME}"
else
    # 备用方法
    echo "使用备用方法创建 DMG..."
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${TEMP_DMG_DIR}" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        "${RELEASE_DIR}/${DMG_NAME}.tmp" 2>/dev/null
    
    hdiutil convert "${RELEASE_DIR}/${DMG_NAME}.tmp" -format UDZO -o "${RELEASE_DIR}/${DMG_NAME}"
    rm -f "${RELEASE_DIR}/${DMG_NAME}.tmp"
    echo "✅ DMG 创建成功: ${RELEASE_DIR}/${DMG_NAME}"
fi

# 清理临时目录
rm -rf "${TEMP_DMG_DIR}"

echo ""
echo "📦 DMG 安装包: ${RELEASE_DIR}/${DMG_NAME}"
echo ""
echo "使用方法："
echo "1. 双击 ${DMG_NAME} 打开"
echo "2. 将 ${APP_NAME}.app 拖拽到 Applications 文件夹"
echo "3. 弹出磁盘镜像"

