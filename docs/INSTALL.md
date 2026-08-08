# Abigent 安装说明

1. 打开 `Abigent.dmg`。
2. 将 Abigent 拖入 Applications。
3. 首次运行时允许通知，Abigent 只在需要操作、完成或失败时提醒。
4. 在 Abigent 设置中点击“启用实时同步”。Abigent 会把自己的 7 个事件合并到 `~/.codex/hooks.json`，不会覆盖 Flux Island 或其他已有 Hook。
5. 辅助功能降级默认关闭，只在需要界面定位或 Hook 未提供的原地回复能力时按需开启。

当前开发构建使用临时签名。对外发布前需使用 Apple Developer ID 签名并公证。

卸载前先在设置中点击“停用 Abigent Hook”，再退出并删除应用。停用只移除带 `com.abigent.desktop` 标记的条目。若要同时清除历史，删除 `~/Library/Application Support/Abigent`。
