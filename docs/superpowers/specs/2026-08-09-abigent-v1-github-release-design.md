# Abigent V1 GitHub 开源发布设计

## 产品定位

Abigent V1 是一个完全本地运行的 macOS Codex 桌面伴侣。用户从 GitHub Releases 下载 DMG、将应用拖入“应用程序”，完成一次本地 Hook 设置并重启 Codex 后，即可通过桌面小猫感知 Codex 的任务进度并查看本轮结果。

V1 定位为个人开源 Beta，不要求 Apple Developer Program 账号。首版仅支持 Apple Silicon 与 macOS 14 及以上版本。

## V1 能力边界

### Codex 任务感知

- 自动发现 Codex 桌面应用和本地会话。
- 通过 Codex Hooks 接收 SessionStart、UserPromptSubmit、PreToolUse、PermissionRequest、PostToolUse、Stop 和 SubagentStop。
- 只在“需要用户操作”和“任务完成”时发送系统通知。
- 桌宠动画区分空闲、工作、需要操作、完成和连接异常。
- 支持多个 Codex 会话；同一会话的多轮结果不会串轮。
- Hook 暂不可用时保留 App Server 与 session 日志恢复能力。

### 任务结果

- 悬停小猫显示本轮回复摘要和实际返回时间。
- 点击或展开后显示完整回复、修改文件和测试结果；没有结构化信息时不臆测。
- 新一轮开始时立即清除上一轮缓存结果。
- Stop 与 session 日志写入不同步时，最多在后台恢复 30 秒。

### 本地化与隐私

- Prompt、Agent 回复、文件列表和测试结果只在本机处理。
- 不上传会话内容，不引入分析 SDK，不要求账号或云服务。
- Hook 通过当前用户的 Unix Socket 与 Abigent 通信；目录权限为 `0700`，Socket 权限为 `0600`。
- 默认不启用辅助功能权限，不读取屏幕像素。

## 桌宠交互

### 移动与缩放

- 拖动小猫主体移动桌面位置。
- 鼠标悬停小猫并在触控板双指点按时，打开品牌化半透明操作框。
- 小猫右下角显示圆形缩放手柄；按住拖动可连续调整大小。
- 操作框提供 50%–150% 的精确缩放滑杆和“恢复默认大小”。
- 大小与桌面位置自动保存在本机，应用重启后恢复。
- 分辨率、显示器或工作区变化后，将小猫限制回可见区域。
- 摘要卡片保持可读字号和固定内容宽度，不跟随小猫同比缩小。

### 操作框

操作框包含：

- 查看本轮结果
- 始终置顶
- 恢复默认大小
- 打开设置
- 隐藏小猫
- 退出 Abigent
- 小猫大小滑杆与当前百分比

双指点按等价于 macOS 的辅助点按；没有触控板时，鼠标右键触发相同操作框。点击操作框外部或按 Escape 关闭。

## 首次安装体验

1. 用户从 GitHub Releases 下载 `Abigent.dmg`。
2. 用户将 Abigent 拖入“应用程序”。
3. 由于 V1 未使用 Developer ID 公证，README 和 DMG 引导用户在系统设置的“隐私与安全性”中确认首次打开。
4. 首次启动页检测 Codex、当前 Hook 状态和本地 Socket。
5. 用户点击“启用实时同步”，Abigent 将自己的命令合并进每个事件首个有效 Hook 分组，并保留现有命令、matcher、顺序和未知字段。
6. 设置成功后明确显示“请完全退出并重新打开 Codex”，直到检测到重启后的真实 SessionStart 才标记接入完成。
7. 提供一条可执行的测试引导：在 Codex 发送任务，观察小猫工作和完成状态，再悬停查看摘要。

升级时保留数据库、桌宠大小、位置和 Hook 配置。卸载 Hook 时只删除包含稳定所有权标记 `com.abigent.desktop` 的条目。

## Hook 共存策略

- Abigent 命令追加到事件的首个现有分组 `hooks` 数组，避免创建 Codex 不执行的末尾分组。
- 若事件没有分组，则创建一个只包含 Abigent 命令的分组。
- 安装和修复操作幂等，每个事件最多存在一个 Abigent 命令。
- Flux Island 与其他第三方命令的解析后语义哈希在安装、修复和卸载前后保持一致。
- JSON 损坏、分组结构异常或写后验证失败时拒绝覆盖原配置。
- 每次写入前创建备份，并使用原子写入。

## 测试与质量门槛

### 自动测试

- Core：状态机、通知策略、新一轮清空旧结果、事件来源优先级。
- Hooks：Socket 权限、同 UID 校验、消息大小限制、Relay 失联不阻断 Codex。
- Installer：首次安装、修复、幂等、首分组合并、Flux 共存、卸载和损坏 JSON。
- Results：闭合 turn、延迟落盘、重复 Stop、串轮防护、损坏行和并发 session。
- Pet：缩放范围、拖动手柄换算、位置持久化、屏幕边界和摘要卡片尺寸。
- Persistence：任务、结果和设置的编码、升级与恢复。

必须在安装完整 Xcode 后运行全部 XCTest。仅生产 target 编译成功不能视为自动测试通过。

### 本机集成测试

- 无 Abigent 历史数据的全新安装。
- 从旧 build 覆盖升级，并验证设置保留。
- 无 Flux、已有 Flux、多个第三方 Hook 三种配置。
- 安装 Hook 前后重启 Codex，验证 SessionStart 到 Stop 的完整链路。
- 新建会话、继续旧会话、多会话并行和同一会话连续多轮。
- 需要权限、任务失败、取消、Abigent 中途退出和 Socket 中断恢复。
- 停用 Abigent Hook 后确认第三方配置不变。

### 视觉与交互测试

- 50%、100%、150% 三档及连续拖动缩放。
- 触控板双指点按和鼠标右键。
- 单显示器、多显示器、不同缩放比例、桌面空间和全屏应用。
- 小猫移动、置顶、隐藏与恢复。
- 摘要卡片在屏幕左右边缘不越界，正文保持可读。

### 发布验收

- Release 模式构建 arm64 应用和嵌套 Helper。
- App 与 Helper 完成临时签名并通过严格验证。
- DMG 包含 Abigent 和 Applications 快捷入口，并通过镜像校验。
- 在一台没有开发环境和历史配置的 Apple Silicon Mac 上完成冒烟测试。
- 发布物生成 SHA-256，并与 GitHub Release 页面一致。

## GitHub 仓库与发布物

仓库包含：

- 源码、Swift Package、测试和构建脚本
- `README.md`：产品介绍、GIF/截图、安装、首次打开、Hook 设置、Codex 重启、使用、卸载和故障诊断
- `PRIVACY.md`：本地数据、权限、网络行为和删除方式
- `LICENSE`：MIT License
- `CHANGELOG.md`：版本变化和已知限制
- `CONTRIBUTING.md`：开发环境、构建、测试和提交方式

GitHub Release 包含：

- `Abigent-v1.0.0-macOS-arm64.dmg`
- `Abigent-v1.0.0-macOS-arm64.dmg.sha256`
- 安装说明、已知限制和变更摘要

## 版本与兼容性

- 首个公开版本：`1.0.0-beta.1`。
- 最低系统：macOS 14.0。
- CPU：Apple Silicon arm64。
- Agent：Codex 桌面应用。
- Trae CN、Intel Mac、自动更新、云同步和 Apple 公证不属于 V1。

## 发布阻断条件

以下任一项未满足时不得发布：

- 完整 XCTest 未通过。
- 新会话或连续多轮出现漏状态、永久转圈或摘要串轮。
- Hook 安装、修复或卸载改变第三方配置语义。
- 全新机器无法按 README 完成安装和首次同步。
- 小猫在缩放、多显示器或重启后不可见。
- DMG、签名或 SHA-256 校验失败。
