# Abigent macOS 14 启动兼容性修复设计

## 背景

`v1.0.0-beta.1` 在 Apple Silicon、macOS 14.8.4 上通过 Gatekeeper 后启动即退出，终端错误为：

```text
AttributeGraph/Attribute.swift:473: Fatal error: attempting to create attribute with no subgraph: External<()>
```

安装包签名完整且 CPU 架构、最低系统版本均符合要求。崩溃发生于 SwiftUI 建立应用视图图谱期间。

## 根因判断

`AbigentApplication` 在 `@StateObject` 属性初始化时同步调用 `AppModel.make()`。`AppModel` 随即构造 `PetWindowController`；控制器初始化时创建 `NSPanel`、创建 `NSHostingView<PetView>` 并渲染窗口。`AppModel.init` 还会立即显示小猫，并排队创建 onboarding 的 SwiftUI hosting view。

这使 SwiftUI hosting graph 在 SwiftUI `App` 自身的 graph 尚未就绪时被嵌套创建。较新 macOS 可以容忍该时序，macOS 14 的 AttributeGraph 会直接触发 fatal error。

## 采用方案

采用“模型构造与 UI 启动分离”的最小兼容修复：

1. `AppModel` 初始化只建立数据依赖、回调和初始状态，不显示窗口、不恢复位置、不连接 Codex、不弹 onboarding。
2. 新增幂等的应用启动入口，由根 SwiftUI 场景完成首次呈现后触发。
3. 启动入口在主线程的后续执行周期中依次：
   - 激活并首次渲染小猫窗口；
   - 恢复保存的位置与缩放；
   - 启动 Codex 与 Hook 连接；
   - 按原有规则显示首次引导。
4. 重复触发启动入口不产生第二个窗口、第二个 socket listener 或第二套任务流。

小猫、菜单栏、设置、悬停摘要、拖动、缩放、Hook 和通知的现有交互保持不变。

## 组件边界

### AbigentApplication

仅负责在根场景完成挂载后通知 `AppModel` 可以启动 UI。它不直接管理窗口或连接器。

### AppModel

继续作为应用状态与业务协调入口，但把现有初始化副作用迁入公开、幂等的启动方法。该方法必须运行在 `MainActor`。

### PetWindowController

构造后可以存在，但构造过程不得建立 SwiftUI hosting view。新增显式启动方法，首次调用时渲染并按当前可见性显示窗口。后续的状态变化仍沿用现有渲染路径。

## 启动数据流

```text
SwiftUI App 创建 StateObject
  → AppModel 构造纯依赖
  → MenuBarExtra 根视图完成挂载
  → AppModel 启动入口（仅一次）
  → PetWindowController 首次渲染/显示
  → 恢复位置与缩放
  → 启动 Codex/Hook
  → 必要时显示 onboarding
```

## 错误处理

- 本地数据库创建失败时维持现有降级提示，不阻止小猫与设置入口显示。
- 恢复位置失败时使用屏幕右下角默认位置。
- Codex 或 Hook 连接失败仍使用现有状态信息与日志恢复。
- 启动入口的重复调用直接返回，避免重复资源。

## 验证

1. 单元级验证：模型构造阶段不触发小猫显示；启动入口幂等。
2. 构建验证：App 与 helper 均为 `arm64`，深度签名校验通过，DMG 可挂载且 SHA-256 正确。
3. 本机回归：首次启动、已有配置启动、退出后重启、小猫拖动/缩放/悬停摘要与操作框。
4. 目标机验收：Apple Silicon、macOS 14.8.4，清除隔离标记后从 `/Applications` 启动，不出现 AttributeGraph fatal error，并显示小猫或首次引导。

## 发布

- 新版本为 `v1.0.0-beta.2`，不覆盖 `beta.1`。
- Release 明确标注修复 macOS 14 启动崩溃。
- 更新 README、CHANGELOG、安装说明与版本发布说明中的下载入口和已知问题。
- 免费临时签名限制不变；首次运行仍可能需要“隐私与安全性 → 仍要打开”或移除隔离属性。

## 非目标

- 不在本次引入 Apple Developer ID、公证或自动更新。
- 不增加 Intel 架构支持。
- 不重构 Codex 连接、结果摘要或窗口交互。
