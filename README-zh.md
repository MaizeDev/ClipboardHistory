# ClipboardHistory

[English](README.md) | **简体中文**

一个轻量、开源、只在本机保存数据的 macOS 剪贴板历史工具。

> 当前最低支持 macOS 15.6。应用不会上传剪贴板内容，也不需要“辅助功能”权限。

## 安装

1. 打开项目的 [Releases 页面](../../releases/latest)。
2. 下载最新的 `ClipboardHistory-v*.dmg`。
3. 打开 DMG，把 `ClipboardHistory` 拖到“应用程序”。
4. 第一次启动后，应用图标会出现在菜单栏。

如果 Release 标记为“未公证测试版”，macOS 可能显示安全提醒。公开发布的正式版应使用 Developer ID 签名并完成 Apple 公证。

## 使用

- 正常复制文字、带格式文字、图片或文件，内容会自动进入本机历史。
- 按 `⇧⌘C` 打开或关闭历史浮窗；菜单栏菜单里也可以暂停记录。
- 输入关键词可搜索内容、文件名或来源应用；长列表的搜索不会阻塞界面。
- Finder 复制的图片、视频和常见文件会尽量显示内容缩略图；一次复制多个文件也可以完整保留。
- 鼠标单击选择卡片，双击按默认方式复制并关闭浮窗。
- 文字卡片始终显示“保留格式”和“纯文本”，鼠标操作时布局不会跳动。
- 每张卡片都可以用图钉临时固定，或用星标长期收藏。
- “历史 / 收藏”选项卡可以分别查看最近内容和长期保存的内容。
- 删除记录后 5 秒内可以通过浮窗底部的“撤销”或 `⌘Z` 恢复。
- 可以在偏好设置里设置最多保留条数、自动删除天数，以及清空历史时是否同时删除数据库备份。
- 特别大的截图会自动压缩后保存，不会因为超过大小上限就直接丢掉。

| 按键 | 功能 |
| --- | --- |
| `↑` / `↓` | 移动选中卡片 |
| `Enter` | 复制选中内容并关闭浮窗 |
| `Option + Enter` | 临时使用另一种文字复制方式 |
| `⌘1`～`⌘9` | 选择前 9 条记录 |
| `Delete` / `Backspace` | 删除选中记录 |
| `⌘P` | 固定或取消固定 |
| `⇧⌘F` | 收藏或取消收藏 |
| `⌘Z` | 撤销删除 |
| `Esc` | 清空搜索；搜索为空时关闭浮窗 |

在菜单栏图标上点击并选择“偏好设置”，可以查看全部快捷键，修改呼出浮窗、固定、收藏和另一种复制方式的快捷键，也可以调整默认复制方式、历史数量、自动删除天数、登录启动以及隐私规则。

## 隐私

- 所有历史数据使用 SwiftData 保存在本机。
- 不包含账户、云同步、统计 SDK 或网络上传功能。
- 自动跳过被来源应用标记为机密、临时或自动生成的剪贴板内容；Apple“密码”等常见密码管理器的内容默认不记录。
- 可以在偏好设置中清空全部记录（可选择同时删除数据库备份），或忽略指定应用。
- 收藏和固定内容不会被自动清理；清空全部历史或手动删除仍会移除它们。
- 数据库升级或修复时会在本机保留最近 5 份备份，备份中可能包含旧历史内容，只保存在这台 Mac 上。

完整说明见 [PRIVACY.md](PRIVACY.md)。

## 从源码构建

需要 macOS、Xcode 26 或更高版本。

1. 使用 Xcode 打开 `ClipboardHistory.xcodeproj`。
2. 等待 Swift Package Manager 取得 `KeyboardShortcuts` 3.0.1。
3. 选择 `ClipboardHistory` scheme 和 `My Mac`。
4. 点击运行。

命令行编译：

```bash
xcodebuild \
  -project ClipboardHistory.xcodeproj \
  -scheme ClipboardHistory \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

运行轻量逻辑测试（不依赖 Xcode 测试 target，覆盖文件路径存储、搜索、历史和撤销恢复）：

```bash
./scripts/run_logic_tests.sh
```

## 发布 DMG

项目提供可重复执行的打包脚本：

```bash
./scripts/package_dmg.sh 1.2.0
```

没有 Developer ID 时，脚本会创建只适合本机验证的临时签名 DMG。正式公开发布的签名和公证方法见 [docs/RELEASING.md](docs/RELEASING.md)。

## 开源许可

本项目使用 [MIT License](LICENSE)。第三方依赖 `KeyboardShortcuts` 同样使用 MIT License。
