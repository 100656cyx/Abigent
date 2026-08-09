# GitHub 首页 Beta 2 展示设计

## 目标

让访问 Abigent GitHub 首页的用户第一眼看到真实使用效果，并明确下载 `v1.0.0-beta.2`，避免误装存在 macOS 14 启动问题的 Beta 1。

## 首屏布局

README 保留项目名称和一句话介绍，随后依次展示：

1. 当前推荐版本提示：`v1.0.0-beta.2`。
2. Beta 1 的 macOS 14 启动兼容性提醒。
3. Beta 2 DMG 直接下载链接与 Release 说明链接。
4. 用户提供的真实使用截图。
5. 原有主要能力、安装、隐私和开发文档。

## 图片资源

- 原始来源：用户提供的 Abigent 使用截图。
- 仓库路径：`docs/assets/abigent-beta2-overview.png`。
- 不裁剪、不重绘、不添加水印。
- README 使用相对路径，确保 GitHub 首页和分支预览均可显示。
- 替代文字说明画面包含 Codex 完成状态、任务摘要和桌面小猫。

## 下载信息

- 推荐版本：`v1.0.0-beta.2`。
- DMG：`Abigent-1.0.0-beta.2-macOS-arm64.dmg`。
- Release：`https://github.com/100656cyx/Abigent/releases/tag/v1.0.0-beta.2`。
- 直接下载：`https://github.com/100656cyx/Abigent/releases/download/v1.0.0-beta.2/Abigent-1.0.0-beta.2-macOS-arm64.dmg`。

## 验证

- 图片被 Git 跟踪且 PNG 可正常解析。
- README 不再把 Beta 1 描述为当前推荐版本。
- README 中 Beta 2 的 Release 与 DMG 链接返回有效资源。
- GitHub `main` 分支首页可以显示截图和下载提示。

## 非目标

- 不修改应用代码、安装包或 Release 附件。
- 不删除 Beta 1 历史发布和说明。
- 不对用户截图进行视觉编辑。
