# Abigent

Abigent 是一个完全在本地运行的 macOS Codex 桌面伴侣。它用一只桌面小猫实时反馈 Agent 的工作、等待操作和完成状态，并在任务完成后展示本轮回复摘要。

![Abigent 小猫](Resources/Pet/abigent-base.png)

## V1 Beta 能力

- 自动监听 Codex 桌面应用的实时任务状态。
- 任务完成后悬停小猫查看本轮摘要、返回时间和完整回复。
- 需要操作与任务完成时发送系统通知。
- 触控板双指点按或鼠标右键打开小猫操作框。
- 拖动小猫移动位置，拖动右下角手柄缩放；大小和位置自动保存。
- 与 Flux Island 和其他 Codex Hooks 共存。
- 所有会话内容仅在本机处理，不需要账号或云服务。

## 系统要求

- Apple Silicon Mac（M1 或更新）。
- macOS 14.0 或更新。
- 已安装 Codex 桌面应用。

## 安装

1. 从 GitHub Releases 下载 `Abigent-v1.0.0-beta.1-macOS-arm64.dmg`。
2. 打开 DMG，将 Abigent 拖入“应用程序”。
3. 首次打开时，如果 macOS 提示无法验证开发者，请打开“系统设置 → 隐私与安全性”，在安全提示旁选择“仍要打开”。这是个人开源 Beta，尚未使用 Apple Developer ID 公证。
4. 按首次设置页点击“启用实时同步”。
5. 使用 `⌘Q` 完全退出 Codex，再重新打开。只关闭窗口不会重新加载 Hooks。
6. 在 Codex 发送一个任务；小猫应开始工作，完成后悬停可查看本轮摘要。

## 小猫操作

- 移动：拖动小猫主体。
- 操作框：触控板双指点按或鼠标右键。
- 缩放：拖动右下角圆形手柄，或使用操作框中的 50%–150% 滑杆。
- 结果：悬停查看摘要；在操作框点击“结果”固定展开。
- 恢复：操作框点击“复原”回到 100%。
- 隐藏后恢复：点击菜单栏的 Abigent 图标，在设置中重新打开“显示桌面宠物”。

## 卸载

先在 Abigent 设置中点击“停用 Abigent Hook”，再退出并删除应用。该操作只删除带有 `com.abigent.desktop` 标记的 Abigent 条目，不修改 Flux Island 或其他 Hooks。

可选本地数据位置：

- 任务数据库：`~/Library/Application Support/Abigent/`
- 本地 Socket：`~/.abigent/`
- Codex Hook 备份：`~/.codex/hooks.abigent.backup.json`

## 故障排查

- 小猫没有动作：确认已完全重启 Codex，并在 Abigent 设置中点击“修复配置”。
- 一直转圈：等待当前 Codex 任务真正结束；若超过 30 秒，重新打开 Abigent。
- 摘要不是本轮：确认使用最新版本，并新发一轮任务测试。
- 小猫不见了：从菜单栏 Abigent 设置打开“显示桌面宠物”。
- 与 Flux 共存：修复前后 Abigent 会保留所有非 Abigent Hook 的命令、匹配器和顺序。

## 本地开发

需要完整 Xcode 和 Swift 6：

```bash
swift test
Scripts/build-app.sh
ABIGENT_VERSION=1.0.0-beta.1 ABIGENT_BUILD=1 Scripts/release.sh
```

参阅 [PRIVACY.md](PRIVACY.md)、[CONTRIBUTING.md](CONTRIBUTING.md) 和 [CHANGELOG.md](CHANGELOG.md)。

## License

MIT
