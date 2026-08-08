# Abigent 安装说明

1. 打开 `Abigent.dmg`。
2. 将 Abigent 拖入 Applications。
3. 首次运行时允许通知，Abigent 只在需要操作、完成或失败时提醒。
4. 辅助功能降级默认关闭。若要感知 Codex 桌面应用的实时状态和原地回复，请在 Abigent 设置中主动开启，再到“系统设置 → 隐私与安全性 → 辅助功能”授权。

当前开发构建使用临时签名。对外发布前需使用 Apple Developer ID 签名并公证。

卸载时先退出 Abigent，再删除 Applications 中的应用。若要同时清除历史，删除 `~/Library/Application Support/Abigent`。
