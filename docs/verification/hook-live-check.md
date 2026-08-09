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

以上项目属于安装与传输的中间检查，不足以证明 Codex 会执行 Abigent Hook：

- `hooks.json` 中存在命令，只证明配置已经写入。
- Socket 存在，只证明 Abigent 服务端已启动。
- 手动调用 Relay，只证明 Relay → Socket → Normalizer → TaskCoordinator 可用。
- Flux Island 等第三方 Hook 正常，只证明该第三方 handler 已执行；Codex 会对同组的每个 handler 单独保存信任状态。

## 下一条真实任务验收

- 在 Codex Hooks 设置中确认七个 Abigent handler 均已信任并启用。
- 创建一条新的真实 Codex 任务；历史任务不会重新发送 Hook。
- 数据库中的对应任务必须由 Hook provenance 更新，不能只依赖 App Server 发现。
- Prompt、Stop 与桌宠状态的延迟不超过 1 秒。
- Stop 后悬停卡显示与 Codex 一致的最终 Agent 回复和返回时间。
- 停用 Abigent Hook 后 Flux Island 条目保持不变。

只有上述真实任务闭环通过，才能标记 Hook 已连接。完整诊断案例见 [Codex Hook 信任排障](../troubleshooting/codex-hook-trust.md)。
