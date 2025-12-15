# 安装指南

## 方法 1: 使用打包脚本创建 .app 应用包（推荐）

### 步骤 1: 运行打包脚本

```bash
cd /Users/tralyfang/Desktop/project/paste_quick
./package.sh
```

这会：
1. 编译应用（release 模式）
2. 创建 `PasteQuick.app` 应用包
3. 自动创建 DMG 磁盘镜像

**跳过 DMG 创建（仅创建 .app）：**
```bash
./package.sh --no-dmg
```

**单独创建 DMG（需要先运行 package.sh）：**
```bash
./package-dmg.sh
```

### 步骤 2: 安装应用

打包完成后，应用包位于 `release/PasteQuick.app`

**方法 A: 使用命令行安装**
```bash
sudo cp -R release/PasteQuick.app /Applications/
```

**方法 B: 手动安装（推荐）**
1. 打开 Finder
2. 导航到 `release` 文件夹
3. 将 `PasteQuick.app` 拖拽到 `/Applications` 文件夹
4. 输入管理员密码（如果需要）

**方法 C: 直接运行（测试用）**
```bash
open release/PasteQuick.app
```

## 方法 2: 使用 DMG 安装（如果创建了 DMG）

1. 双击 `release/PasteQuick-1.0.dmg` 打开磁盘镜像
2. 将 `PasteQuick.app` 拖拽到 Applications 文件夹
3. 弹出磁盘镜像

## 首次运行

1. **打开应用**
   - 在 Launchpad 或 Applications 文件夹中找到 PasteQuick
   - 双击运行

2. **授予权限**
   - 系统会请求"辅助功能"权限（用于粘贴功能）
   - 前往：**系统设置 > 隐私与安全性 > 辅助功能**
   - 添加 PasteQuick 并勾选

3. **开始使用**
   - 应用会在菜单栏显示图标
   - 使用 `⌘ + Shift + V` 快捷键唤出窗口

## 卸载

### 方法 1: 使用 Finder
1. 打开 Applications 文件夹
2. 将 `PasteQuick.app` 拖到废纸篓
3. 清空废纸篓

### 方法 2: 使用命令行
```bash
sudo rm -rf /Applications/PasteQuick.app
```

## 常见问题

### Q: 提示"无法打开，因为无法验证开发者"？

**解决方法：**
1. 右键点击 `PasteQuick.app`
2. 选择"打开"
3. 在对话框中点击"打开"

或者设置允许运行未签名的应用：
```bash
sudo xattr -rd com.apple.quarantine /Applications/PasteQuick.app
```

### Q: 应用无法获得权限？

**解决方法：**
1. 确保应用在 `/Applications` 目录下
2. 前往：系统设置 > 隐私与安全性 > 辅助功能
3. 如果 PasteQuick 在列表中，取消勾选后重新勾选
4. 如果不在列表中，点击"+"添加应用

### Q: 快捷键不工作？

**解决方法：**
1. 确认应用正在运行（查看菜单栏图标）
2. 检查是否有其他应用占用相同的快捷键
3. 重启应用

### Q: 如何设置开机自启动？

**手动设置：**
1. 打开"系统设置"
2. 进入"通用 > 登录项"
3. 点击"+"添加 PasteQuick

**或使用命令行：**
```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/PasteQuick.app", hidden:false}'
```

