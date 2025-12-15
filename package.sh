#!/bin/bash

# PasteQuick 打包脚本 - 创建可安装的 .app 应用包

set -e

APP_NAME="PasteQuick"
BUNDLE_ID="com.pastequick.app"
VERSION="1.0"
BUILD_DIR=".build"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
RELEASE_DIR="release"

echo "🚀 开始打包 ${APP_NAME}..."

# 清理之前的构建和打包
if [ -d "${BUILD_DIR}" ]; then
    echo "清理之前的构建..."
    rm -rf "${BUILD_DIR}"
fi

if [ -d "${APP_DIR}" ]; then
    echo "清理之前的应用包..."
    rm -rf "${APP_DIR}"
fi

if [ -d "${RELEASE_DIR}" ]; then
    echo "清理之前的发布目录..."
    rm -rf "${RELEASE_DIR}"
fi

# 构建可执行文件
echo "📦 编译应用..."
swift build -c release

if [ ! -f "${BUILD_DIR}/release/${APP_NAME}" ]; then
    echo "❌ 错误：找不到构建的可执行文件"
    exit 1
fi

# 创建应用图标（如果不存在）
if [ ! -f "AppIcon.icns" ] && [ ! -f "AppIcon.png" ]; then
    echo "🎨 创建应用图标..."
    if [ -f "create-icon-simple.sh" ]; then
        ./create-icon-simple.sh
    elif [ -f "create-icon.sh" ]; then
        ./create-icon.sh
    else
        echo "⚠️  警告：找不到图标创建脚本，跳过图标创建"
    fi
fi

# 创建应用包结构
echo "📁 创建应用包结构..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 复制可执行文件
echo "📋 复制可执行文件..."
cp "${BUILD_DIR}/release/${APP_NAME}" "${MACOS_DIR}/"

# 复制 Info.plist
echo "📋 复制 Info.plist..."
cp "Info.plist" "${CONTENTS_DIR}/"

# 复制应用图标
if [ -f "AppIcon.icns" ]; then
    echo "📋 复制应用图标 (.icns)..."
    cp "AppIcon.icns" "${RESOURCES_DIR}/"
elif [ -f "AppIcon.png" ]; then
    echo "⚠️  警告：使用 PNG 格式图标，建议转换为 .icns 格式以获得最佳效果"
    echo "📋 复制应用图标 (PNG)..."
    cp "AppIcon.png" "${RESOURCES_DIR}/"
    echo "   💡 提示：查看 ICON.md 了解如何创建 .icns 文件"
else
    echo "⚠️  警告：未找到应用图标文件"
fi

# 设置可执行文件权限
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 创建发布目录并移动应用包
mkdir -p "${RELEASE_DIR}"
mv "${APP_DIR}" "${RELEASE_DIR}/"

echo ""
echo "✅ 打包完成！"
echo ""
echo "应用包位置: ${RELEASE_DIR}/${APP_DIR}"
echo ""
echo "安装方法："
echo "1. 直接安装："
echo "   sudo cp -R '${RELEASE_DIR}/${APP_DIR}' /Applications/"
echo ""
echo "2. 手动安装："
echo "   将 '${RELEASE_DIR}/${APP_DIR}' 拖拽到 /Applications 文件夹"
echo ""
echo "3. 直接运行："
echo "   open '${RELEASE_DIR}/${APP_DIR}'"
echo ""

# 可选：创建 DMG 磁盘镜像（可以通过参数跳过）
CREATE_DMG=true
if [ "$1" == "--no-dmg" ]; then
    CREATE_DMG=false
fi

if [ "$CREATE_DMG" = true ]; then
    DMG_NAME="${APP_NAME}-${VERSION}.dmg"
    DMG_PATH="${RELEASE_DIR}/${DMG_NAME}"
    
    echo "🎨 创建 DMG 磁盘镜像..."
    
    # 创建临时目录用于 DMG
    TEMP_DMG_DIR="temp_dmg"
    rm -rf "${TEMP_DMG_DIR}"
    mkdir -p "${TEMP_DMG_DIR}"
    
    # 复制应用和创建快捷方式
    cp -R "${RELEASE_DIR}/${APP_DIR}" "${TEMP_DMG_DIR}/"
    ln -s /Applications "${TEMP_DMG_DIR}/Applications"
    
    # 创建 DMG
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${TEMP_DMG_DIR}" \
        -ov -format UDZO \
        "${DMG_PATH}" 2>/dev/null || {
        # 如果 hdiutil 失败，尝试使用不同的方法
        hdiutil create -volname "${APP_NAME}" \
            -srcfolder "${TEMP_DMG_DIR}" \
            -fs HFS+ \
            -fsargs "-c c=64,a=16,e=16" \
            -format UDRW \
            "${DMG_PATH}.tmp" 2>/dev/null
        
        hdiutil convert "${DMG_PATH}.tmp" -format UDZO -o "${DMG_PATH}"
        rm -f "${DMG_PATH}.tmp"
    }
    
    # 清理临时目录
    rm -rf "${TEMP_DMG_DIR}"
    
    echo "✅ DMG 创建完成: ${DMG_PATH}"
    echo ""
    echo "DMG 安装方法："
    echo "1. 双击 ${DMG_NAME} 打开"
    echo "2. 将 ${APP_NAME}.app 拖拽到 Applications 文件夹"
    echo "3. 弹出并删除 DMG 文件"
fi

echo ""
echo "🎉 所有打包任务完成！"

