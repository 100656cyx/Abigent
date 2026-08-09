# Abigent 免费个人分享与 GitHub 发布设计

日期：2026-08-09

## 发布定位

Abigent 以个人开源 Beta 形式免费分享，不加入 Apple Developer Program，不使用 Developer ID 与 Apple 公证。发布物采用临时签名，接收者首次打开时需要通过 macOS“系统设置 → 隐私与安全性 → 仍要打开”确认一次。

该版本不能承诺无警告安装；README 和安装包必须明确说明这一限制，不引导用户使用关闭 Gatekeeper 或删除隔离属性等绕过命令。

## 分享安装包

发布物为 Apple Silicon DMG：

- `Abigent-1.0.0-beta.1-macOS-arm64.dmg`
- `Abigent-1.0.0-beta.1-macOS-arm64.dmg.sha256`

DMG 根目录包含：

- `Abigent.app`
- `Applications` 拖放快捷入口
- `首次打开说明.txt`

安装说明覆盖：系统要求、拖入应用程序、首次尝试打开、在“隐私与安全性”点击“仍要打开”、启用实时同步、完整重启 Codex、验证小猫状态和摘要。

## 打包安全边界

- 继续对内置 `abigent-hook` 和外层 App 使用临时签名与 Hardened Runtime，确保打包后的内部代码结构一致。
- 创建 DMG 后执行 `codesign --verify --deep --strict`、Helper 签名检查、arm64 检查、`hdiutil verify` 和 SHA-256 校验。
- 不把 Apple ID、密码、证书、私钥或本机路径写入仓库或产物。
- 不在安装脚本中自动修改 Gatekeeper、quarantine 或系统安全设置。

## GitHub 仓库内容

更新以下内容：

- `README.md`：最新能力、固定小猫窗口、独立摘要浮层、右键滑块、免费安装步骤、故障排查、正确构建命令。
- `INSTALL.md`：面向非开发者的完整中文安装、首次打开、Codex 连接、升级与卸载指南。
- `CHANGELOG.md`：记录 build 2–5 的悬停稳定、独立浮层和首次设置修复。
- `docs/releases/1.0.0-beta.1.md`：可直接粘贴到 GitHub Release 的发布说明、下载文件、系统要求和已知限制。
- `.github/workflows/build.yml`：持续集成继续运行测试与构建，并增加 DMG、签名和架构验证；CI 产物明确标记为未公证。
- `.github/workflows/release.yml`：手动输入版本和 build，生成免费分享 DMG、校验文件并上传为 Actions artifact，不自动创建公开 Release。
- `.gitignore`：忽略本地项目上下文文件 `AGENTS.md`，避免误上传。

保留 MIT License、隐私说明和贡献指南。

## 构建脚本

- `Scripts/create-dmg.sh` 在临时 staging 目录加入仓库中的安装说明模板。
- 新增 `Resources/Distribution/首次打开说明.txt` 作为 DMG 内文件的唯一来源。
- `scripts/release.sh` 继续生成版本化 DMG 和 SHA-256，不改变当前本地调用方式。
- README 中统一使用实际路径：`Scripts/build-app.sh` 与 `scripts/release.sh`。

## GitHub 发布步骤

1. 确认仓库没有证书、凭据、个人会话、数据库、构建产物和项目上下文文件。
2. 推送源代码与工作流。
3. 在本机或 GitHub Actions 手动生成分享 DMG。
4. 创建 GitHub Release `v1.0.0-beta.1`。
5. 粘贴准备好的发布说明，上传 DMG 与 SHA-256。
6. 在另一台 Apple Silicon Mac 按 INSTALL 指南完成干净安装验证。

本轮只准备仓库与产物，不自动创建 GitHub 仓库、不推送、不公开发布。

## 验证

- 挂载 DMG 后能看到 App、Applications 和首次打开说明。
- DMG 与校验文件匹配，映像验证通过。
- App 与 Helper 临时签名严格校验通过，主程序仅为 arm64。
- README、INSTALL、Release Notes 中的文件名、版本、系统要求和操作步骤一致。
- GitHub workflow YAML 可解析，脚本在 macOS runner 上使用正确的大小写路径。
- Git 状态不包含 `AGENTS.md`、`dist/`、本机数据库、Socket 或用户会话。

## 非目标

- 不实现 Developer ID 签名或 Apple 公证。
- 不上架 Mac App Store。
- 不自动绕过 Gatekeeper。
- 不在本轮推送 GitHub 或创建公开 Release。
