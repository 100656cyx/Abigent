# Abigent V1 Beta 已知限制

日期：2026-08-09

1. 安装包使用临时签名，没有 Apple Developer ID 与公证。其他用户首次打开时可能被 Gatekeeper 拦截，需要按照 README 中的“仍要打开”步骤操作。
2. 当前仅支持 Apple Silicon 和 macOS 14 及以上，不包含 Intel 架构。
3. 当前版本只正式支持 Codex；Trae CN 连接器属于后续版本范围。
4. Codex 安装或更新 Hooks 后，需要重新打开 Codex，并产生一个真实会话事件，首次设置才会显示连接完成。
5. 本机缺少完整 Xcode，自动化 XCTest 尚未执行；测试源码已经保留。
6. 全新用户、另一台干净 Mac 与真实多显示器拔插流程尚需补充手工验收。
7. 图标构建在当前 Command Line Tools 环境中会回退使用 PNG 资源，不影响应用启动与功能。
