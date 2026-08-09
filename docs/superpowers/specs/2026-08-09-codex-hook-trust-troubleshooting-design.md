# Codex Hook 信任排障文档设计

## 背景

在 `v1.0.0-beta.2` 实机使用中，出现 Codex 会话正常执行、Flux Island 能实时同步、Abigent 进程和本地 Socket 正常，但小猫完全没有任务状态的情况。

诊断确认：Abigent 的七个命令已经写入 `~/.codex/hooks.json`，但 Codex 会为每个 Hook handler 单独记录信任状态。Flux Island 位于组内位置 `0:0` 且已信任，Abigent 位于 `0:1` 且未信任，因此 Codex 只执行 Flux Island handler。用户在 Codex 中信任并启用 Abigent Hooks、完全重启 Codex 后，同步恢复。

## 目标

让用户和维护者能够识别“Hook 已写入但未获信任”这一独立状态，避免把配置存在、Socket 存在或第三方 Hook 正常误判为 Abigent 已连接。

## 文档结构

### README 快速排障

在“故障排查”中增加一条短说明：当其他 Hook 正常而 Abigent 不同步时，进入 Codex Hooks 设置，逐项信任并启用命令中包含 `Abigent.app/Contents/Helpers/abigent-hook` 的 handler，然后用 `⌘Q` 完全重启 Codex。

### INSTALL 安装与验证

在连接 Codex 的步骤中明确区分：

1. Abigent 已将配置写入 `hooks.json`。
2. Codex 已信任并启用 Abigent handler。
3. Abigent 已收到一条真实会话事件。

列出七个事件名称，并说明信任 Flux Island 不等于信任同组的 Abigent handler。

### 完整排障案例

新增 `docs/troubleshooting/codex-hook-trust.md`，记录：

- 用户可见现象与环境。
- 具有误导性的正常信号。
- 从会话、第三方 Hook、Abigent 进程、Socket、数据库到 Relay 的分层诊断顺序。
- `hooks.state` 中位置化 handler 信任记录的根因。
- 用户解决步骤。
- 维护者应遵循的验收标准与隐私边界。

案例不包含 Prompt、回复正文、用户名、绝对个人路径或真实会话 ID。

### Hook 验收文档

更新 `docs/verification/hook-live-check.md`：配置合并、Socket 创建和 Relay 自测只是中间检查；发布验收必须由真实 Codex 会话证明 Hook provenance 进入 Abigent 数据库，并验证任务状态与 Stop 结果。

## 产品经验

后续首次设置应把 Hook 连接拆成三态：

```text
配置已写入
等待 Codex 信任
已收到真实事件
```

本次只更新文档，不修改应用 UI 或 Hook Installer；三态检测作为后续产品迭代候选。

## 验收

- README、INSTALL、完整案例和 Hook 验收文档表述一致。
- 七个事件名称完整且与当前安装器一致。
- 不把手动 Relay 自测描述成真实 Hook 已连接。
- 不建议绕过 Codex Hook 信任机制或直接篡改 trusted hash。
- 文档不泄露真实用户任务内容与会话标识。
