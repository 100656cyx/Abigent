# Abigent 实现总结

## 产品闭环

Abigent 同时提供桌面宠物和菜单栏入口。宠物用于低打扰状态感知，菜单栏用于任务列表、确认、回复、结果与控制。普通运行过程只改变宠物动作；首次进入“需要操作”“完成”或“失败”时才发送通知。

## Codex 连接

`CodexProcessTransport` 通过本机 `codex app-server --stdio` 建立 JSON-RPC v2 通道，逐行解码消息，按请求 ID 路由响应，并在进程退出时结束所有等待请求。`CodexConnector` 使用 `thread/list` 自动发现任务，使用 turn 生命周期映射状态，并处理命令授权和 `requestUserInput` 的原始服务器请求 ID。

真实验证发现：独立 App Server 能读取本机任务，但 Codex 桌面自己的 App Server 通过 stdio 私有连接到桌面进程，没有公开共享 Socket。因此历史发现和结构化数据走 App Server；实时开始与完成状态由 `CodexSessionWatcher` 监听本机 `.codex/sessions` 追加日志中的事件类型、时间和任务 ID，不读取或上传对话正文。定位和桌面拥有的输入请求可使用默认关闭的 `CodexAccessibilityFallback`，它只搜索 macOS 辅助功能角色与标签，不读取像素或依赖坐标。

## 统一任务核心

`AgentConnector` 隔离不同 Agent 的协议。`AgentTask` 统一表示来源、标题、项目、状态、待处理请求、可信结果和时间。`TaskReducer` 拒绝串错任务的事件并忽略旧状态；缺少来源数据时保持空值，不猜测进度、文件或测试结果。

第二版接入 Trae CN 时实现新的 `TraeCNConnector`，向 Task Core 输出同样的快照和事件，并复用全部界面、通知、存储与宠物逻辑。

## 本地数据与恢复

`TaskRepository` 使用系统 SQLite3、WAL 和参数化语句保存 Codable 任务快照。任务以更新时间做条件更新，旧事件不能覆盖新状态。通知收据使用稳定键去重。`TaskCoordinator` 在启动时合并数据库与来源快照；断线后活动任务进入 `connectionUnknown`，不会被误判完成。

## 菜单栏与原地操作

SwiftUI `MenuBarExtra` 将任务按需要操作、运行中和最近完成排序。确认卡显示原始问题和选项，只有用户点击后才调用连接器；文本草稿在来源确认成功前不会丢失。结果卡分别展示摘要、明确提供的文件信息和测试信息，缺失时标记“未运行/未提供”。

## 桌面宠物

`PetWindowController` 使用透明、无边框、跨 Space 的 AppKit `NSPanel`。`PetAnimationState` 按需要操作、断线、运行、完成、空闲的优先级聚合任务。半写实角色由用户小猫照片生成，保留大耳朵、金色眼睛、暖灰棕毛色和修长比例。首版使用一张透明高质量基础图，配合 SwiftUI 缩放、旋转、位移和语义徽记实现五种状态；系统“减少动态效果”开启后自动使用静态画面。

## 权限与安全

通知按需请求。辅助功能由用户在设置中主动开启，代码在未开启或未授权时立即拒绝操作。权限选择永不自动批准。应用不请求全磁盘访问，不包含网络客户端 entitlement，也不保存 Codex 凭据。

## 构建和发布

`Scripts/build-app.sh` 使用 SwiftPM release 构建，生成 `Abigent.app`、资源包和应用图标，随后签名并验证；无法由当前工具链生成 ICNS 时会安全回退为 PNG 图标。`Scripts/create-dmg.sh` 在受控临时目录创建带 Applications 链接的 DMG 并校验。未配置 `ABIGENT_SIGNING_IDENTITY` 时使用临时签名；正式分发仍需 Developer ID 和 Apple 公证。

## 测试与已知限制

核心、传输、映射、辅助权限、SQLite 和协调器均包含 XCTest 测试源码。当前 Command Line Tools 不包含 XCTest，完整自动化测试需要安装完整 Xcode；所有生产 target 已使用兼容 SDK 完成编译和链接检查。独立 App Server 无法直接订阅桌面进程的实时事件，因此实时状态使用本地会话日志；等待输入的结构化问题和原地回复在桌面私有连接未开放时仍需要用户明确授权的辅助功能桥。精确 Codex thread 深链尚无官方格式，当前“打开 Codex”会激活应用并由辅助功能定位任务。
