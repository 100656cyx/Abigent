# Abigent Hook 实时同步与桌宠结果卡设计

日期：2026-08-08  
状态：待用户审阅

## 目标

将 Abigent 从“任务发现与状态观察器”升级为“本地实时 Agent 事件中心”。Codex 任务开始、工具执行、等待操作和完成时，由 Hook 主动把结构化事件发送给 Abigent；任务完成后，用户把鼠标停在小猫上即可看到本次返回的结论、时间和验证信息，并可展开完整结果。

首版升级只实现 Codex。所有跨 Agent 数据继续进入现有 `AgentConnector`、`AgentTask` 和 `TaskCoordinator`，为下一版 Trae CN 全局 Hooks 保留相同接口。

## 成功标准

- Codex 提交 Prompt 后，Abigent 在 1 秒内显示工作状态。
- 权限申请或用户输入请求在 1 秒内显示需要操作状态。
- Codex Stop 后，Abigent 在 1 秒内显示完成或失败，并记录 Agent 的实际返回时间。
- 本次任务的最后一条 Agent 返回可在桌宠悬停卡中查看；默认显示 3–5 行，点击可展开全文。
- 重启 Abigent 后，可以从本地会话记录恢复最近结果，但不会把陈旧的未闭合任务恢复为永久运行中。
- Abigent 不覆盖或删除 Flux Island、用户或其他工具已有的 Hook。
- 所有事件、内容、Socket 和数据库只存在本机，不新增网络上传。

## 观察结论与设计依据

本机 Flux Island 使用 IDE Hook 主动推送，而不是仅依赖窗口识别或轮询。它为 Codex 注册 `SessionStart`、`UserPromptSubmit`、`PreToolUse`、`PermissionRequest`、`PostToolUse`、`Stop` 和 `SubagentStop`，由本地 relay 发送到 Unix Socket。Trae/Trae CN 使用 IDE 全局 Hooks 接入同一事件中心。

Abigent 借鉴这种通用架构模式，但独立实现自己的协议、脚本和存储，不复制 Flux Island 的代码、私有格式或品牌资源。

## 总体架构

```text
Codex hooks.json
    │
    │ JSON 事件，经 stdin 传给 abigent-hook
    ▼
Abigent Hook Relay
    │
    │ NDJSON over Unix domain socket
    ▼
Abigent Local Event Server
    │
    ├── HookEventNormalizer
    ├── CodexResultExtractor
    └── TaskCoordinator
            │
            ├── SQLite
            ├── 通知
            ├── 菜单栏任务卡
            └── 桌宠悬停结果卡

恢复通道：Codex App Server 快照＋本地 session JSONL
兜底通道：用户明确开启的 macOS 辅助功能
```

数据源优先级为：Hook 实时事件 > App Server 结构化快照 > session 日志恢复 > 辅助功能界面兜底。同一任务的事件以来源优先级和观察时间归约，低优先级旧事件不能覆盖高优先级新状态。

## Hook 安装与共存

### 文件

- Hook 配置：`~/.codex/hooks.json`
- Abigent Relay：应用包 `Contents/Helpers/abigent-hook`
- 本地 Socket：`~/Library/Application Support/Abigent/run/bridge.sock`
- 安装收据：`~/Library/Application Support/Abigent/hook-installation.json`

### 合并规则

安装器按事件逐项合并，只管理带稳定标记 `com.abigent.desktop` 的 Hook 条目：

- 保留所有无法识别和非 Abigent 条目，包括 Flux Island。
- 已存在同版本 Abigent 条目时不重复添加。
- 升级时仅替换旧 Abigent 条目。
- 卸载时仅删除 Abigent 自己的条目；空数组和空对象才做结构清理。
- 写入前验证 JSON，创建同目录备份并使用原子替换。
- 如果现有文件无法解析，停止安装并在界面中解释，不重建或覆盖。

Hook 属于持久化集成，首次启用前必须在 Abigent 设置中由用户明确点击。界面展示将修改的配置路径、事件列表和“可随时停用”说明。

## 本地事件协议

Relay 从 stdin 读取 Codex Hook JSON，添加 Abigent 协议包络后发送到 Unix Socket：

```json
{
  "schemaVersion": 1,
  "source": "codex",
  "event": "Stop",
  "sessionID": "...",
  "observedAt": "2026-08-08T15:00:00Z",
  "payload": {}
}
```

- Socket 目录权限为当前用户可读写，拒绝非当前 UID 客户端。
- 单条消息设置大小上限，格式错误只丢弃该条并记录本地诊断。
- Relay 连接失败时快速退出，不阻塞 Codex 正常工作。
- `PermissionRequest` 等阻塞事件的首版只负责展示，不替 Codex 自动批准。
- 事件使用 NDJSON 分帧，支持同一 Socket 上连续发送。

## Codex 事件映射

| Hook | Abigent 行为 |
|---|---|
| `SessionStart` | 关联会话、项目、进程和任务 |
| `UserPromptSubmit` | 创建或更新任务，进入 `working` |
| `PreToolUse` | 更新当前活动，不展示未经确认的结果 |
| `PermissionRequest` | 进入 `needsInput`，展示原始问题和选项 |
| `PostToolUse` | 记录已完成活动，可补充文件和测试证据 |
| `Stop` | 提取最后 Agent 回复，进入 `completed` 或 `failed` |
| `SubagentStop` | 更新子任务；主任务仍运行时不误报整体完成 |

Hook Payload 字段缺失时保持未知，不根据文案猜测文件、测试或进度。事件必须能关联到已知 session/task；无法关联的事件先进入短期缓冲，快照到达后再合并。

## 结果提取

`CodexResultExtractor` 在 Stop 后读取对应 session JSONL 的新增区间，目标是最后一个已闭合 turn：

- 最后一条 `assistant` 文本作为完整结果 `detail`。
- 第一段或前 160 个字符作为 `summary`，不调用云端模型二次总结。
- 明确的 `fileChange`/补丁事件生成 `changedFiles`，去重并保留顺序。
- 只有存在明确测试命令及其退出结果时才生成测试摘要；否则显示“未提供”。
- `completedAt` 使用 Stop Hook 的实际接收时间，同时保留来源事件时间用于诊断。
- 记录已消费文件偏移，避免每次重新扫描整个会话。

若完整内容暂时尚未写入 session 文件，最多进行短暂、有限次数重试；仍不可用时先显示“任务已完成，结果同步中”，随后补发结果事件。

## 桌宠悬停结果卡

### 交互

- 鼠标进入小猫命中区域后延迟约 180 ms 展开，避免划过时闪烁。
- 默认卡片显示当前需要操作的任务；否则显示最近完成任务；工作中则显示当前活动。
- 卡片默认宽约 360 pt，展示 3–5 行摘要。
- 鼠标离开小猫和卡片后延迟约 250 ms 收起，允许鼠标从小猫移动到卡片。
- 点击卡片或“展开”进入固定状态，显示可滚动全文；点击外部或关闭按钮解除固定。
- 卡片自动选择小猫左侧或右侧，保证在当前屏幕可见区域内。

### 内容

- Codex 标识、项目名称和任务标题。
- 工作中、需要操作、完成、失败或连接异常状态。
- Agent 本次返回的摘要或同步占位状态。
- 实际返回时间，使用本机时区。
- 修改文件数量和测试结果，仅在来源明确时展示。
- 快捷操作：“查看完整结果”“打开 Codex”；需要操作时展示安全的选项或文本回复入口。

### 隐私

悬停卡可能包含源代码或业务内容。设置中增加“悬停显示结果”开关，默认开启；锁屏或屏幕共享自动隐藏正文的能力不纳入本轮，后续单独设计。

## 状态与错误处理

- Hook Server 不可用：Relay 快速失败，Codex 不受影响；Abigent 显示“Hook 未连接”并继续使用日志恢复。
- Codex 配置被外部修改：安装器下次检查时重新做三方合并，不覆盖第三方内容。
- Stop 到达但结果未写完：显示完成与“结果同步中”，有限重试后保留明确提示。
- Abigent 崩溃或重启：Socket 文件安全重建；使用收据、数据库和 session 偏移恢复。
- 同时运行多个 Agent：按 `GlobalTaskID` 隔离；桌宠优先级为需要操作 > 运行中 > 最近完成 > 连接异常 > 空闲。
- 历史未闭合 session：超过时效且文件未更新时恢复为已发现，不进入永久 working。

## 测试与验收

### 自动测试

- Hook JSON 合并、升级、卸载和不可解析配置保护。
- Unix Socket 分帧、断线、消息上限和当前用户校验。
- 每类 Codex Hook 到 `AgentEvent` 的映射。
- Stop 结果提取、延迟写入、文件去重和无测试结果场景。
- 多任务事件隔离、乱序和重复事件归约。
- 悬停延迟、固定/解除、屏幕边界定位和任务选择优先级。

### 本机验收

1. 保留 Flux Island Hook，启用 Abigent Hook，确认双方条目共存。
2. 在 Codex 提交任务，核对 Hook 时间与小猫状态变化不超过 1 秒。
3. 触发权限申请，确认 Abigent 只展示、不自动批准。
4. 完成包含文本、文件修改和测试的任务，核对悬停卡内容与 Codex 一致。
5. 重启 Abigent，确认最近结果恢复且旧任务不会持续转圈。
6. 停用 Abigent Hook，确认 Flux Island 和其他 Hook 完全保留。

## 本轮边界

- 实现 Codex Hook、结果提取、悬停摘要卡和完整结果展开。
- 不在本轮实现 Trae CN，但协议和安装器接口必须支持增加 `TraeCNHookAdapter`。
- 不自动批准命令或权限。
- 不复制 Flux Island 代码或依赖它运行。
- 不做云端同步、账号系统、遥测后台或远程控制。
