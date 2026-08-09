# Contributing

感谢参与 Abigent。

## 开发环境

- Apple Silicon Mac
- macOS 14+
- 完整 Xcode（包含 XCTest）
- Swift 6

## 验证

提交前运行：

```bash
swift test
Scripts/build-app.sh
bash -n Scripts/*.sh
```

不得提交用户 session 日志、Hook 配置、数据库、构建目录或发布产物。新增功能应包含聚焦的 XCTest，并保持所有 Agent 数据本地化。

## 提交

使用小而明确的提交。Bug 报告请包含 Abigent 版本、macOS 版本、可复现步骤和脱敏后的错误信息；不要上传 Prompt、Agent 回复或项目源码。
