# Abigent MVP 发布验收

日期：2026-08-08

- Release 模式下全部生产 target 编译并链接成功。
- `dist/Abigent.app` 已完成临时签名，`codesign --verify --deep --strict` 通过。
- 从打包后的 `.app` 启动成功，主进程保持运行。
- 宠物 PNG 与 SwiftPM 资源包已包含在应用 Resources 目录。
- `dist/Abigent.dmg` 创建成功，包含 Abigent 与 Applications 快捷入口。
- `hdiutil verify` 校验 DMG 成功。
- 0.2.0 安装包包含独立签名的 `Contents/Helpers/abigent-hook`，外层严格签名校验通过。
- 已安装 0.2.0 并确认主进程、小猫资源、Hook Socket 启动和工作状态显示正常。
- 当前机器只有 Command Line Tools，缺少 XCTest；测试源码已提交，但完整 XCTest 运行等待安装完整 Xcode。
- 面向外部用户发布前，仍需使用 Developer ID Application 签名并完成 Apple 公证。
