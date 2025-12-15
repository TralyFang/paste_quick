#!/bin/bash

# PasteQuick 构建脚本

set -e

echo "构建 PasteQuick..."

# 清理之前的构建
if [ -d ".build" ]; then
    echo "清理之前的构建..."
    rm -rf .build
fi

# 使用 Swift Package Manager 构建
echo "使用 Swift Package Manager 构建..."
swift build -c release

echo "构建完成！"
echo ""
echo "要运行应用，请执行："
echo "  .build/release/PasteQuick"
echo ""
echo "或者使用 Swift 直接运行："
echo "  swift run -c release"

