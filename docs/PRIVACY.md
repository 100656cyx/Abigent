# Abigent 隐私说明

- Abigent 的连接器、任务归一化、历史、通知和界面都在用户 Mac 上运行。
- Abigent 不建设业务服务器，不上传 Prompt、回复、代码路径、任务结果或使用行为。
- 任务数据保存在 `~/Library/Application Support/Abigent/tasks.sqlite`。
- Codex Hook 事件通过权限为当前用户专用的本地 Unix Socket 传递，不开放网络端口。Hook 内容仅用于本机任务状态与结果展示。
- 最终 Agent 回复保存在本机任务数据库，用于小猫悬停结果卡；可在设置中关闭悬停正文显示。
- 诊断输出只包含事件类别、状态、数量和任务 ID 的 SHA-256，不输出 Prompt、回复、仓库路径、账号或令牌。
- Abigent 不复制 Codex 登录凭据。Codex 自身与 OpenAI 的既有网络通信不经过 Abigent。
- 辅助功能桥默认关闭，只使用 macOS 语义化角色与标签，不进行屏幕像素识别。
