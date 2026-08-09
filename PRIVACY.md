# Abigent 隐私说明

Abigent 完全在用户的 Mac 本地运行。

## 本地读取

Abigent 读取 Codex 的本地任务状态、Hook 事件和 session JSONL，用于显示工作状态、本轮回复、修改文件和测试结果。它还读取 `~/.codex/hooks.json`，仅用于安全安装、修复或移除自己的 Hook 条目。

## 本地保存

Abigent 在 `~/Library/Application Support/Abigent/` 保存任务缓存和安装回执，在 UserDefaults 保存桌宠位置、大小与显示偏好，在 `~/.abigent/` 创建当前用户专用 Socket。

## 网络与遥测

Abigent 不上传 Prompt、回复、代码、文件列表、测试结果或使用数据。V1 不包含账号、分析 SDK、遥测、广告、云同步或自动更新。

## 权限

默认不需要辅助功能、屏幕录制、摄像头或麦克风权限。可选的辅助功能降级默认关闭，且不读取屏幕像素。

## 删除数据

先在设置中停用 Abigent Hook，再删除应用。用户也可以手动删除 `~/Library/Application Support/Abigent/`、`~/.abigent/` 和 Abigent 的 UserDefaults。
