#!/bin/bash

# 创建应用图标的脚本（优先使用简化版）
# 如果简化版失败，请使用此脚本

echo "⚠️  建议使用 create-icon-simple.sh 来创建图标"
echo "   如果需要完整的 .icns 支持，请使用 Xcode 或在线工具"

if [ -f "create-icon-simple.sh" ]; then
    ./create-icon-simple.sh
else
    echo "❌ 错误：找不到 create-icon-simple.sh"
    exit 1
fi
