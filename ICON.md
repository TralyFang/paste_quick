# 应用图标说明

## 当前状态

应用使用 `Sources/PasteQuick/assets/icon.jpg` 作为图标源文件。

## 图标格式

macOS 应用需要使用 `.icns` 格式的图标文件。我们已经创建了一个简化脚本来自动生成，但某些系统上可能无法成功生成 `.icns` 文件。

## 生成图标的方法

### 方法 1: 使用简化脚本（推荐）

```bash
./create-icon-simple.sh
```

这会尝试生成 `.icns` 文件，如果失败则生成 `AppIcon.png`。

### 方法 2: 使用 Xcode

1. 打开 Xcode
2. 创建一个新的 macOS App 项目（仅用于图标）
3. 将 `Sources/PasteQuick/assets/icon.jpg` 导入到 Assets.xcassets
4. 导出 `.icns` 文件
5. 将 `.icns` 文件重命名为 `AppIcon.icns` 并放到项目根目录

### 方法 3: 使用在线工具

可以使用在线工具将 PNG 转换为 .icns：
- https://cloudconvert.com/png-to-icns
- https://iconverticons.com/

步骤：
1. 运行 `./create-icon-simple.sh` 生成 `AppIcon.png`
2. 使用在线工具将 `AppIcon.png` 转换为 `AppIcon.icns`
3. 将 `AppIcon.icns` 放到项目根目录

### 方法 4: 使用 iconutil（手动）

如果系统支持，可以手动创建：

```bash
# 创建图标集目录
mkdir -p .icon-assets/AppIcon.iconset

# 生成不同尺寸的图标
sips -z 16 16 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_16x16.png
sips -z 32 32 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_32x32.png
sips -z 64 64 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_128x128.png
sips -z 256 256 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_256x256.png
sips -z 512 512 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 Sources/PasteQuick/assets/icon.jpg --out .icon-assets/AppIcon.iconset/icon_512x512@2x.png

# 创建 Contents.json（参考 create-icon.sh 中的格式）

# 生成 .icns
iconutil -c icns .icon-assets/AppIcon.iconset -o AppIcon.icns
```

## 打包时自动处理

运行 `./package.sh` 时，如果根目录不存在 `AppIcon.icns` 或 `AppIcon.png`，脚本会自动运行图标创建脚本。

## 图标要求

- 推荐尺寸：1024x1024 像素
- 格式：.icns（必需）或 .png（临时方案）
- 位置：项目根目录，命名为 `AppIcon.icns` 或 `AppIcon.png`

## 注意事项

- `.icns` 文件会被复制到应用包的 `Contents/Resources/` 目录
- `Info.plist` 中已配置图标文件名为 `AppIcon`
- 如果使用 PNG 格式，macOS 可能无法正确显示图标，建议使用 .icns 格式

