#!/bin/bash

# 简化版图标创建脚本
# 直接使用 PNG 格式作为应用图标（macOS 支持）

set -e

ICON_SOURCE="Sources/PasteQuick/assets/icon.jpg"
ICNS_FILE="AppIcon.icns"

echo "🎨 创建应用图标..."

# 检查源文件是否存在
if [ ! -f "${ICON_SOURCE}" ]; then
    echo "❌ 错误：找不到图标源文件 ${ICON_SOURCE}"
    exit 1
fi

# 清理旧的图标文件
rm -f "${ICNS_FILE}" "AppIcon.png"

# 先创建一个高质量的 PNG 图标（1024x1024）
echo "📐 生成图标文件..."
sips -z 1024 1024 "${ICON_SOURCE}" --out "AppIcon.png" > /dev/null 2>&1 || sips -Z 1024 "${ICON_SOURCE}" --out "AppIcon.png" > /dev/null 2>&1

if [ -f "AppIcon.png" ]; then
    echo "✅ PNG 图标创建成功: AppIcon.png"
    
    # 尝试使用 Python 创建简单的 .icns（如果可用）
    if command -v python3 &> /dev/null; then
        echo "📦 尝试生成 .icns 文件..."
        python3 << 'PYTHON'
import subprocess
import os

# 创建临时目录
iconset = ".icon-assets/AppIcon.iconset"
os.makedirs(iconset, exist_ok=True)

# 生成不同尺寸
sizes = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for size, name in sizes:
    subprocess.run(
        ["sips", "-z", str(size), str(size), "AppIcon.png", 
         "--out", f"{iconset}/{name}"],
        capture_output=True
    )

# 创建 Contents.json
contents = {
    "images": [
        {"idiom": "mac", "scale": "1x", "size": "16x16", "filename": "icon_16x16.png"},
        {"idiom": "mac", "scale": "2x", "size": "16x16", "filename": "icon_16x16@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "32x32", "filename": "icon_32x32.png"},
        {"idiom": "mac", "scale": "2x", "size": "32x32", "filename": "icon_32x32@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128x128.png"},
        {"idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_128x128@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256x256.png"},
        {"idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_256x256@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512x512.png"},
        {"idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_512x512@2x.png"},
    ],
    "info": {"author": "xcode", "version": 1}
}

import json
with open(f"{iconset}/Contents.json", "w") as f:
    json.dump(contents, f, indent=2)

# 尝试生成 .icns
result = subprocess.run(
    ["iconutil", "-c", "icns", iconset, "-o", "AppIcon.icns"],
    capture_output=True
)

if result.returncode == 0 and os.path.exists("AppIcon.icns"):
    print("✅ .icns 文件创建成功")
    import shutil
    shutil.rmtree(iconset, ignore_errors=True)
else:
    print("⚠️  .icns 创建失败，将使用 PNG 格式")
PYTHON
    fi
    
    if [ -f "AppIcon.icns" ]; then
        rm -f "AppIcon.png"
        echo "✅ 图标创建完成: AppIcon.icns"
    else
        echo "✅ 图标创建完成: AppIcon.png (将使用 PNG 格式)"
    fi
else
    echo "❌ 错误：图标创建失败"
    exit 1
fi

