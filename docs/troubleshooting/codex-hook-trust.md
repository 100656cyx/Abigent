# Codex Hook 已配置但 Abigent 不同步

## 典型现象

- Codex 会话正常工作并产生最终回复。
- Abigent 正常运行，桌面小猫可见。
- `~/.codex/hooks.json` 中存在 Abigent 的七个事件。
- `~/.abigent/run/bridge.sock` 存在。
- Flux Island 或其他工具可以同步同一条 Codex 任务。
- Abigent 小猫却没有进入工作状态，任务也没有进入 Abigent 数据库。

这些信号看起来像 Abigent 已经完成连接，但仍可能缺少 Codex 对 Abigent handler 的单独信任。

## 根因

Codex 对每一个 Hook handler 独立保存启用与信任状态。Hook 的身份包含来源文件、事件、matcher group 位置和 handler 位置。

例如，同一个 `UserPromptSubmit` matcher group 可以包含：

```text
handler 0: Flux Island
handler 1: Abigent
```

handler 0 已获信任，不会自动让 handler 1 获得信任。结果可能是：

```text
Codex 触发事件
  ├─ Flux Island：已信任，正常执行
  └─ Abigent：未信任，不执行
```

因此，“第三方 Hook 正常”和“Abigent 配置存在”都不能证明 Abigent Hook 已连接。

## 用户解决方法

1. 确认安装的是最新 Abigent Beta。
2. 打开 Codex 设置中的 Hooks 管理页面。
3. 找到命令中包含以下路径的 handler：

```text
Abigent.app/Contents/Helpers/abigent-hook
```

4. 信任并启用这些 Abigent handler：

```text
SessionStart
UserPromptSubmit
PreToolUse
PermissionRequest
PostToolUse
Stop
SubagentStop
```

5. 使用 `⌘Q` 完全退出 Codex。
6. 重新打开 Codex并发送一个新任务。

历史任务的 Hook 不会自动重放，必须用新任务验证。

不要直接编辑 Codex 保存的信任哈希，也不要使用绕过 Hook 信任的启动参数。信任操作应该由用户在 Codex 中明确完成。

## 分层诊断方法

维护者应按照以下顺序判断断点，避免看到某一个正常信号就提前结束诊断。

### 1. 会话是否真实存在

确认 Codex 已创建对应本地会话，并且本轮有开始和完成事件。这能排除用户记错会话或任务尚未真正开始。

### 2. Codex 是否触发 Hooks

如果另一个工具收到了同一会话的 `SessionStart`、`UserPromptSubmit` 或 `Stop`，可以证明 Codex Hook dispatcher 正常，但不能证明 Abigent handler 被执行。

### 3. Abigent 服务是否在线

确认 Abigent 进程存在，并且本地 Socket 已创建：

```text
~/.abigent/run/bridge.sock
```

Socket 存在只能证明服务端正在监听。

### 4. Relay 传输是否正常

使用不含真实 Prompt 的临时诊断事件，可以独立验证：

```text
Relay → Unix Socket → Normalizer → TaskCoordinator → SQLite
```

诊断任务必须使用专用测试 ID，并在验证后删除。Relay 自测成功仍不代表 Codex 实际执行了该 handler。

### 5. 数据来源是否真的是 Hook

App Server 也可能发现任务，所以“数据库中存在任务”仍然不够。必须确认真实新任务由 Hook provenance 更新，并且 Prompt、Stop 与桌宠状态的延迟符合预期。

### 6. 检查每个 handler 的信任状态

如果 Codex dispatcher、Abigent 服务和 Relay 链路分别正常，但真实事件没有进入 Abigent，应检查 Abigent handler 是否处于未信任或未启用状态。不要根据同组第一个 handler 的状态推断后续 handler。

## 本案例的诊断结论

本案例中：

- Codex 会话和 Hook dispatcher 正常。
- 第三方 Hook 正常收到完整生命周期事件。
- Abigent App、Socket 和签名正常。
- 手动 Relay 诊断能够写入临时任务。
- 真实任务没有 Hook provenance。
- Codex 只保存了同组第一个 handler 的信任记录，Abigent handler 没有获信任。

用户在 Codex 中信任 Abigent Hooks、完全重启 Codex并发送新任务后，桌面同步恢复。

## 产品与验收经验

首次设置不能把“写入 `hooks.json`”直接显示为“连接成功”。更准确的产品状态是：

```text
配置已写入
等待 Codex 信任
已收到真实事件
```

发布验收也必须包含一次真实 Codex 新任务，验证开始状态、小猫反馈、Stop、结果提取和 Hook provenance。配置文件、Socket 和 Relay 自测都只能作为中间证据。
