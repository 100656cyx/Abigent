# Abigent 安装指南

本指南适用于从 GitHub Release 或可信分享者获得的免费个人分享版。

## 1. 安装前确认

- 使用 Apple Silicon Mac（M1 或更新）。
- 系统为 macOS 14.0 或更新。
- 已安装 Codex 桌面应用。
- 下载文件名为 `Abigent-1.0.0-beta.1-macOS-arm64.dmg`。

## 2. 安装 Abigent

1. 双击 DMG。
2. 将 `Abigent.app` 拖到 `Applications`。
3. 从“应用程序”文件夹打开 Abigent，不要直接从 DMG 中长期运行。

## 3. 允许首次打开

免费分享版没有 Apple Developer ID 和公证，因此第一次打开可能看到“无法验证开发者”或“Apple 无法检查是否包含恶意软件”。

1. 先尝试打开 Abigent 一次，然后关闭 macOS 的提示。
2. 打开“系统设置 → 隐私与安全性”。
3. 向下滚动到安全性区域。
4. 在 Abigent 的提示旁点击“仍要打开”。
5. 在确认框中点击“打开”。

不要关闭 Gatekeeper，也不要执行来源不明的终端命令。若 Mac 由公司管理，“仍要打开”可能被管理员禁用。

## 4. 连接 Codex

1. 在 Abigent 首次设置中点击“启用实时同步”。
2. Abigent 会把自己的 Hook 条目安全合并到 `~/.codex/hooks.json`。
3. 使用 `⌘Q` 完全退出 Codex；只关闭窗口不够。
4. 重新打开 Codex。
5. 进入任意会话发送一个任务。
6. 小猫显示工作状态，任务完成后悬停可查看本轮摘要。

首次设置只自动出现一次。以后需要检查连接时，可从 Abigent 设置手动打开。

## 5. 基本操作

- 按住小猫拖动：移动位置。
- 悬停：查看独立摘要浮层。
- 双指点按或鼠标右键：显示操作框。
- 操作框大小滑块：调整为 50%–150%。
- 操作框“复原”：恢复 100%。

## 6. 升级

1. 完全退出 Abigent。
2. 打开新版 DMG。
3. 将新版拖入“应用程序”，选择“替换”。
4. 若 macOS 再次要求安全确认，重复第 3 节。

任务数据库和小猫位置默认会保留。

## 7. 卸载

1. 打开 Abigent 设置，点击“停用 Abigent Hook”。
2. 退出并删除 `/Applications/Abigent.app`。
3. 如需完全清理，可删除：

```text
~/Library/Application Support/Abigent/
~/.abigent/
```

Abigent 只移除自己的 Hook 标记，不删除 Flux Island 或其他工具的 Hook。

## 8. 校验下载文件

如果同时下载了 `.sha256` 文件，可在 DMG 所在目录运行：

```bash
shasum -a 256 -c Abigent-1.0.0-beta.1-macOS-arm64.dmg.sha256
```

输出 `OK` 表示文件与发布者生成的校验值一致；这不能替代 Developer ID 公证，但能发现传输损坏或文件被替换。

