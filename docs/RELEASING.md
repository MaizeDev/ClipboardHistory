# 发布 ClipboardHistory

正式发布顺序是：完成人工验收、生成 Release 构建、Developer ID 签名、Apple 公证、创建 DMG、上传 GitHub Release。

## 准备条件

- Xcode 26 或更高版本
- Apple Developer Program 账号
- 钥匙串中存在 `Developer ID Application` 证书
- GitHub CLI 已登录目标账号

检查证书：

```bash
security find-identity -p codesigning -v
```

## 创建测试 DMG

没有 Developer ID 时，可以先创建临时签名版本供项目所有者验证：

```bash
./scripts/package_dmg.sh 1.2.0
```

输出位于 `dist/ClipboardHistory-v1.2.0.dmg`。这个文件不应标记为已公证正式版。

DMG 使用固定的 Finder 图标布局：左侧是 ClipboardHistory，右侧是“应用程序”文件夹，中间使用箭头提示拖动安装。背景由项目脚本直接生成，卷内不放置安装说明文件。

## 创建签名并公证的 DMG

先在钥匙串保存一次公证凭据：

```bash
xcrun notarytool store-credentials ClipboardHistory-notary
```

然后执行：

```bash
DEVELOPER_ID_APPLICATION='Developer ID Application: 你的开发者名称 (TEAMID)' \
NOTARY_PROFILE='ClipboardHistory-notary' \
./scripts/package_dmg.sh 1.2.0
```

脚本会签名应用、创建 DMG、提交 Apple 公证并附加票据。

## 发布到 GitHub

确认人工验收完成并检查工作区内容，然后创建对应版本的 tag 和 Release，把 `dist/ClipboardHistory-v版本号.dmg` 作为附件上传。

回退方式：如果发布后发现严重问题，将 GitHub Release 标为草稿或删除附件，并恢复到上一个可用 tag；不要用同一个 tag 静默替换不同代码。
