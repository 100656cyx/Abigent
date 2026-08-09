# Abigent V1 Beta 测试矩阵

日期：2026-08-09  
候选版本：`1.0.0-beta.2`（build 7）
目标平台：Apple Silicon、macOS 14 及以上

| 范围 | 结果 | 验证记录 |
|---|---|---|
| Release 构建 | 通过 | 全部生产 target 编译、链接并完成临时签名。 |
| 安装与启动 | 通过 | `dist/Abigent.app` 安装到 `/Applications/Abigent.app` 后正常启动。 |
| 版本与架构 | 通过 | 版本 `1.0.0-beta.2`、build `7`、Mach-O arm64。 |
| 首次连接引导 | 通过 | 能识别已安装 Hooks，并显示“等待 Codex 首个真实事件”。 |
| 桌面宠物 | 通过 | 小猫窗口出现；Codex 工作时显示工作状态。 |
| 操作框 | 通过 | 在小猫上双指按下/右键后显示品牌操作框、大小百分比和滑块。 |
| 自由缩放 | 通过（实现与界面） | 支持 50%–150% 滑块和右下角拖拽手柄；位置与比例持久化。 |
| 本地 Hook 链路 | 通过 | Relay → 本地 Socket → 事件归一化 → 任务协调器已完成实机验证。 |
| Socket 权限 | 通过 | `~/.abigent/run` 为 `0700`，`bridge.sock` 为 `0600`。 |
| 第三方 Hooks 共存 | 通过 | 安装前后非 Abigent Hook 规范化哈希保持一致。 |
| DMG 完整性 | 通过 | SHA-256 与校验文件一致，`hdiutil verify` 通过。 |
| 应用与 Helper 签名 | 通过 | 外层应用严格校验通过，内置 `abigent-hook` 校验通过。 |
| 免费分享 DMG | 通过 | 包含 App、Applications 快捷入口和首次打开说明；SHA-256 与映像验证通过。 |
| 自动化单元测试 | 阻断 | 当前机器只有 Command Line Tools，缺少 `XCTest`；需安装完整 Xcode 后运行。 |
| 全新用户/全新 Mac | 待验证 | 需要在未安装过 Abigent 的 Apple Silicon Mac 上走完整安装、连接、卸载流程。 |
| 多显示器手工测试 | 待验证 | 已实现屏幕变化后的边界纠正，仍需真实双屏/拔插场景验收。 |

## 发布判断

当前产物可作为个人项目的 Beta 候选包供本机试用；在自动化测试和干净机器验收完成前，不标记为稳定版。
