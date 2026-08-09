# Abigent 首次设置完成状态设计

日期：2026-08-09

## 问题

当前首次设置只有在 `.ready` 页面点击“开始使用”时才写入 `onboardingCompleted`。用户直接关闭窗口后，即使后续任务监听正常，完成状态仍未保存；下次启动会再次自动弹出并等待新的 `SessionStart`。

## 目标

- 首次设置窗口最多自动展示一次，不在每次启动时打扰用户。
- 真实 Codex Hook 事件能够自动证明连接有效，不要求用户再点击确认。
- 设置页面继续提供手动重新打开入口，便于诊断或重新配置。

## 状态与持久化

使用两个独立的本地偏好：

- `onboardingAutoShown`：首次自动展示窗口时立即写入。后续启动不再自动展示，与连接是否完成无关。
- `onboardingCompleted`：收到任意真实 Codex Hook 事件，或用户在成功页点击“开始使用”时写入。

这两个值只存储在本机 `UserDefaults`，不上传任何信息。

## 启动规则

- `onboardingAutoShown == false` 时，启动后自动打开首次设置，并立即将它写为 `true`。
- `onboardingAutoShown == true` 时不自动打开。
- 设置页“打开首次设置”始终可以手动打开，不修改自动展示记录。
- 已经完成连接的用户手动打开时，直接显示 `.ready`，不重新进入等待状态。

## 真实事件验证

- Hook Socket 收到任意可解析的真实事件时，调用统一的 `markOnboardingVerified()`。
- 该方法写入 `onboardingCompleted = true`，将状态更新为 `.ready`。
- 如果首次设置窗口正在显示，则自动关闭；小猫和任务处理不受影响。
- 不再只依赖 `SessionStart`，因为用户已经实际收到 Prompt、Tool 或 Stop 等事件时，同样足以证明链路有效。

## 手动行为

- “开始使用”仍调用完成方法并关闭窗口，保证旧流程兼容。
- 用户直接点击窗口关闭按钮时不标记连接完成，但由于 `onboardingAutoShown` 已记录，下次启动不会自动弹出。
- 若 Hooks 未安装或连接异常，用户仍能从设置中再次打开并修复。

## 验证

- 清除两个偏好后启动：窗口自动出现一次，`onboardingAutoShown` 立即存在。
- 关闭窗口并重启：窗口不再自动出现。
- 手动从设置打开：窗口正常出现。
- 收到 UserPromptSubmit、Stop 或其他真实 Hook 事件：写入 `onboardingCompleted`，打开的首次设置窗口自动关闭。
- 已完成用户从设置打开：直接显示“Abigent 已连接”。
- Codex 状态监听、摘要、小猫窗口和 Hook 合并逻辑回归通过。

## 非目标

- 不改变 Hook 安装格式或事件协议。
- 不引入账号、云端状态或遥测。
- 不删除设置中的首次设置入口。
