# Abigent Codex 最终回复恢复设计

## 背景

Codex Hook 已能把 `Stop` 事件和正确的 `session_id` 实时送达 Abigent，会话 JSONL 中也包含最终 `agent_message`。当前实现只在 Stop 后进行约 1.85 秒的有限读取，失败由 `try?` 静默吞掉，因此桌宠会长期停留在“任务已完成，结果同步中”。

## 目标

- Stop 后优先即时显示 Codex 最终回复。
- 日志延迟写入或短暂不可读时，在 30 秒内自动补偿恢复。
- 同一 Stop 或同一结果重复到达时不重复入库、通知或刷新。
- 全部处理保持本地化，不改变 Flux Island 或其他 Hook 配置。
- 无法恢复时保留明确的同步中状态，并留下不含回复正文的本地诊断信息。

## 方案

### 结果恢复器

将一次性提取扩展为按 session 管理的恢复任务：

1. 收到 Stop 后立即尝试读取对应 session JSONL。
2. 如果最新 turn 已有非空 `agent_message`，即刻生成 `TaskResult`。
3. 如果 `task_complete` 或最终消息尚未落盘，按短间隔退避继续读取，最长 30 秒。
4. 新 Stop 到达同一 session 时取消旧恢复任务并以新的 Stop 时间重启，避免上一轮结果串入下一轮。
5. 成功、超时或应用退出时结束恢复任务。

### 提取规则

- 首选最后一个已闭合 turn 中最后一条非空 `agent_message`。
- 日志存在最终 `agent_message`、但 `task_complete` 暂未写入时，仅在 Stop 已到达的前提下允许将该消息作为候选；后续重读仍以闭合 turn 为准。
- `returnedAt` 使用 Stop Hook 的接收时间。
- 摘要取最终回复首个非空行，最多 160 个字符；完整正文写入 detail。
- 文件与测试信息沿用已有提取逻辑；没有结构化信息时不臆测。

### 数据流与并发

`AppModel` 把 Stop 交给独立的结果恢复协调器。协调器以 session ID 保存一个可取消任务，成功后产生 `.result` Hook 事件并交给 `TaskCoordinator`。数据库的 `task_id` 唯一约束和协调器的事件去重共同保证幂等。

如果当前 Codex 进程尚未热加载新安装的 Hook，App Server 的完成状态同样启动结果恢复。该降级事件使用 App Server provenance，避免低优先级恢复结果被协调器拒绝；一旦 Hook 已生效，Hook provenance 仍保持最高优先级。

Hook Socket 使用 `~/.abigent/run/bridge.sock`。该路径与 Flux Island 的用户目录 Socket 模式一致，可由 Codex Hook 子进程访问；数据库等应用数据仍保留在 Application Support。Socket 目录和文件分别保持 `0700` 与 `0600`。

### 错误处理

- session ID 非法或日志不存在：进入恢复周期，而不是立即永久失败。
- 临时读取或 JSON 行损坏：跳过单行并继续有限重试。
- 30 秒仍失败：停止重试，保留“结果同步中”，记录错误类别、session ID、次数和时间；不记录用户回复正文。
- App Server 后续提供结果时，仍可正常补齐。

## 验证

- 已完整写入日志：Stop 后 1 秒内显示精确最终回复。
- `task_complete` 延迟写入：后台自动补齐，最长不超过 30 秒。
- 只有最终 `agent_message` 先写入：可在 Stop 后恢复，不串入上一轮。
- 重复 Stop：只保存一个结果，不产生重复通知。
- 两个 session 同时完成：恢复任务互不影响。
- 无日志、损坏行和应用重启场景不崩溃。
- 实机发送一条新 Codex 任务，悬停小猫可见摘要、完整回复和返回时间。

## 非目标

- 本次不改宠物视觉、卡片布局或通知策略。
- 本次不增加 Trae CN 接入。
- 本次不读取屏幕像素，也不上传任何会话内容。
