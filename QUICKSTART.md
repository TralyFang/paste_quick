# 快速开始指南

## 立即运行

### 方法 1: 直接运行（开发模式）

```bash
cd /Users/tralyfang/Desktop/project/paste_quick
swift run
```

### 方法 2: 构建后运行（发布模式）

```bash
cd /Users/tralyfang/Desktop/project/paste_quick
swift build -c release
.build/release/PasteQuick
```

### 方法 3: 使用构建脚本

```bash
cd /Users/tralyfang/Desktop/project/paste_quick
./build.sh
.build/release/PasteQuick
```

## 首次运行步骤

1. **运行应用**
   ```bash
   swift run
   ```

2. **授予权限**
   - 系统可能会请求辅助功能权限
   - 前往：系统设置 > 隐私与安全性 > 辅助功能
   - 添加 PasteQuick 并勾选

3. **使用快捷键**
   - 按 `⌘ + Shift + V` 唤出窗口
   - 或者点击菜单栏图标

## 测试应用

1. 复制一些文本或图片
2. 按 `⌘ + Shift + V` 打开历史窗口
3. 使用方向键选择条目
4. 按 Enter 粘贴

## 项目结构

```
paste_quick/
├── Sources/
│   └── PasteQuick/
│       ├── main.swift              # 应用入口
│       ├── AppDelegate.swift       # 应用委托
│       ├── Models/
│       │   └── PasteboardItem.swift    # 数据模型
│       ├── Managers/
│       │   ├── PasteboardManager.swift # 粘贴板管理
│       │   └── HotKeyManager.swift     # 快捷键管理
│       └── Views/
│           └── MainWindow.swift        # 主窗口 UI
├── Package.swift                    # Swift Package 配置
├── Info.plist                      # 应用信息
├── build.sh                        # 构建脚本
├── README.md                       # 项目说明
├── USAGE.md                        # 使用指南
└── QUICKSTART.md                   # 本文件
```

## 下一步

- 查看 [README.md](README.md) 了解完整功能
- 查看 [USAGE.md](USAGE.md) 了解详细使用方法
- 修改代码以自定义快捷键或其他功能

## 故障排除

### 编译错误

如果遇到编译错误，请确保：
- macOS 13.0+ 
- Xcode 14.0+ 或最新的 Swift 工具链
- 已安装命令行工具：`xcode-select --install`

### 权限问题

如果快捷键不工作：
1. 检查应用是否在运行（菜单栏图标）
2. 确保没有其他应用占用相同的快捷键
3. 重启应用

如果粘贴不工作：
1. 授予辅助功能权限
2. 重启应用

## 开发提示

- 修改快捷键：编辑 `HotKeyManager.swift` 中的 `RegisterEventHotKey` 调用
- 修改历史记录数量：编辑 `PasteboardManager.swift` 中的 `maxItems` 常量
- 修改窗口大小：编辑 `AppDelegate.swift` 中的窗口尺寸

