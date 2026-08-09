# Abigent MVP 发布验收

日期：2026-08-09

- Release 模式下全部生产 target 编译并链接成功。
- `dist/Abigent.app` 已完成临时签名，`codesign --verify --deep --strict` 通过。
- 从打包后的 `.app` 启动成功，主进程保持运行。
- 宠物 PNG 与 SwiftPM 资源包已包含在应用 Resources 目录。
- `dist/Abigent.dmg` 创建成功，包含 Abigent 与 Applications 快捷入口。
- `hdiutil verify` 校验 DMG 成功。
- 0.2.0 安装包包含独立签名的 `Contents/Helpers/abigent-hook`，外层严格签名校验通过。
- 已安装 0.2.0 并确认主进程、小猫资源、Hook Socket 启动和工作状态显示正常。
- 0.2.1 已完成生产构建、临时签名和 DMG 校验，并安装到 `/Applications/Abigent.app`（build 3）。
- 0.2.1 将 Hook Socket 迁移到 `~/.abigent/run/bridge.sock`；实机权限为 `0600`，安装包 Relay 的本地链路验证为 Hook provenance 3。
- 最终回复提取支持 Stop 早于 `task_complete` 落盘，并由每 session 独立的最长 30 秒恢复任务补齐延迟结果。
- 当前机器只有 Command Line Tools，缺少 XCTest；测试源码已提交，但完整 XCTest 运行等待安装完整 Xcode。
- `1.0.0-beta.2`（build 7）免费分享包已生成，版本、arm64 架构、应用和 Helper 临时签名均已验证。
- 首次设置正确识别 Hook 状态；桌面小猫与双指按下/右键操作框已通过实际界面验收。
- 版本化 DMG 的 SHA-256 和 `hdiutil verify` 均通过。
- DMG 已确认包含 Abigent、Applications 快捷入口和《首次打开说明》。
- 作为个人开源 Beta 可采用未公证分发，并在 README 提示 Gatekeeper 打开方式；若未来追求无警告安装，再使用 Developer ID Application 签名并公证。
- 标记稳定版前仍需：完整 Xcode 下执行 XCTest、干净 Apple Silicon Mac 安装测试、真实多显示器拔插测试。
