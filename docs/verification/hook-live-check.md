# Abigent Hook 实时同步验收

日期：2026-08-09

## 构建前检查

- Abigent Hook 采用稳定所有权标记 `com.abigent.desktop`。
- 安装器只合并或删除自有条目，损坏 JSON 时拒绝写入。
- 0.2.1 起本地 Socket 位于 `~/.abigent/run/bridge.sock`，目录权限 `0700`、Socket 权限 `0600`，可由 Codex Hook 子进程访问。
- Relay 缺少服务端时快速成功退出，不阻断 Codex。

## 实机安装记录

- 启用前 Flux Island/非 Abigent Hook 规范化 SHA-256：`83d23361af2d9ada434ce20563e7d7eef4db07646551a8b00f2dccddb16bca59`。
- 启用后 Flux Island/非 Abigent Hook 规范化 SHA-256：`83d23361af2d9ada434ce20563e7d7eef4db07646551a8b00f2dccddb16bca59`，语义哈希一致。
- 七个 Abigent Hook 事件各存在一次：SessionStart、UserPromptSubmit、PreToolUse、PermissionRequest、PostToolUse、Stop、SubagentStop。
- 安装回执和启用前备份均已生成。
- 本地 Socket 已创建，文件权限为 `0600`。
- 0.2.1 安装后使用安装包内 Relay 发送本地 `PreToolUse`，数据库来源由 App Server（2）提升为 Hook（3），验证 Relay → Socket → Normalizer → TaskCoordinator 链路成功。

## 下一条真实任务验收

- Prompt、Stop 与桌宠状态的延迟不超过 1 秒。
- Stop 后悬停卡显示与 Codex 一致的最终 Agent 回复和返回时间。
- 停用 Abigent Hook 后 Flux Island 条目保持不变。
