# Abigent

Abigent 是一个完全在本地运行的 macOS Agent 桌面管理入口。它自动发现 Codex 任务，以半写实小猫桌宠和菜单栏面板反馈任务状态，并在需要操作或完成时提醒用户。

## 当前能力

- 自动发现本机 Codex 历史任务。
- 统一显示运行、需要输入、完成、失败、取消和连接未知状态。
- 原地处理 Codex 快捷选项与文本回复。
- 展示结果摘要、明确提供的修改文件和测试结果。
- SQLite 本地历史、断线恢复和通知去重。
- 半写实 Abigent 透明桌宠，支持五种状态反馈。
- 完全本地的数据处理；Abigent 不提供中转服务器或遥测后台。

## 构建

```bash
Scripts/build-app.sh
Scripts/create-dmg.sh dist/Abigent.app
```

详细安装、隐私和实现说明见 `docs/INSTALL.md`、`docs/PRIVACY.md` 与 `docs/IMPLEMENTATION.md`。
