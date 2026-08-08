# Abigent MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local-only macOS menu-bar and desktop-pet application that discovers Codex desktop tasks, surfaces attention and completion events, allows replies, and ships as an installable app.

**Architecture:** A Swift package contains an Agent-independent `TaskCore`, a process-backed JSON-RPC `CodexConnector`, persistence and notification coordinators, and a native SwiftUI/AppKit application. The connector talks to the locally installed `codex app-server proxy`; all Codex protocol details remain outside the UI and core model. Work proceeds as a tracer bullet: prove the live Codex round trip first, then add the production UI, pet, persistence, recovery, and packaging.

**Tech Stack:** Swift 6.1, Swift Package Manager, SwiftUI, AppKit, UserNotifications, SQLite3, XCTest, Codex App Server JSON-RPC v2, shell packaging scripts.

## Global Constraints

- Target macOS only; deployment target is macOS 14.0 or newer.
- Use native Swift, SwiftUI, and AppKit; do not introduce Electron, Tauri, or a web runtime.
- Abigent stores and processes its data locally and has no product-owned backend.
- First release supports Codex desktop only; all source-specific behavior lives behind `AgentConnector`.
- Active progress never triggers a notification; only `needsInput`, `completed`, and `failed` do.
- Never invent progress percentages, test outcomes, changed files, or completion state.
- Permission approvals are never automatic; every approval shows the exact task and response.
- Accessibility fallback remains disabled unless the user explicitly enables and grants it.
- Do not add or modify files under `sources/`.
- Do not commit `AGENTS.md`, `.superpowers/`, build output, user data, generated secrets, or captured prompts.
- Xcode is not currently selected on this Mac. Command-line core work can proceed, but native `.app` archive, signing, notarization, and UI automation require installing/selecting full Xcode before Tasks 6–9 can be fully verified.

## Planned File Structure

```text
Package.swift                         SwiftPM products and test targets
Sources/AbigentCore/                  Agent-neutral models and state reducer
Sources/AbigentCodex/                 JSON-RPC transport and Codex mapping
Sources/AbigentPersistence/           SQLite task repository
Sources/AbigentApp/                   SwiftUI app, menu bar, cards, settings
Sources/AbigentApp/Pet/               AppKit pet window and state animation
Sources/AbigentDiagnostics/           CLI used for live protocol verification
Tests/AbigentCoreTests/               Reducer and notification policy tests
Tests/AbigentCodexTests/              Framing, mapping, and fixture tests
Tests/AbigentPersistenceTests/        Database migration and recovery tests
Tests/AbigentAppTests/                View-model and UI policy tests
Fixtures/Codex/                       Synthetic, redacted JSON-RPC fixtures
Resources/Pet/                        Reviewed Abigent illustration assets
Scripts/build-app.sh                  Reproducible unsigned app bundle
Scripts/create-dmg.sh                 DMG packaging
docs/verification/                    Live Codex and release evidence
docs/IMPLEMENTATION.md                Final capability and architecture handoff
```

---

### Task 1: Establish the Swift workspace and Agent contract

**Files:**
- Create: `Package.swift`
- Create: `Sources/AbigentCore/AgentModels.swift`
- Create: `Sources/AbigentCore/AgentConnector.swift`
- Test: `Tests/AbigentCoreTests/AgentModelsTests.swift`

**Interfaces:**
- Produces: `AgentTask`, `TaskState`, `AttentionRequest`, `TaskResult`, `AgentEvent`, and `AgentConnector` used by every later task.
- Consumes: No application code.

- [ ] **Step 1: Add a failing model round-trip test**

```swift
import XCTest
@testable import AbigentCore

final class AgentModelsTests: XCTestCase {
    func testAgentTaskRoundTripsWithoutLosingSourceIdentity() throws {
        let task = AgentTask(
            id: .init(source: .codex, sourceTaskID: "thread-1"),
            source: .codex,
            sourceTaskID: "thread-1",
            projectName: "vibe",
            title: "Build Abigent",
            state: .working,
            attentionRequest: nil,
            result: nil,
            startedAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            completedAt: nil,
            muted: false
        )
        let decoded = try JSONDecoder().decode(AgentTask.self, from: JSONEncoder().encode(task))
        XCTAssertEqual(decoded, task)
        XCTAssertEqual(decoded.id.rawValue, "codex:thread-1")
    }
}
```

- [ ] **Step 2: Run the test and verify the target is missing**

Run: `swift test --filter AgentModelsTests`

Expected: FAIL because `Package.swift` and `AbigentCore` do not exist.

- [ ] **Step 3: Add the package, models, and connector contract**

`Package.swift` must declare macOS 14, libraries `AbigentCore`, `AbigentCodex`, `AbigentPersistence`, executable targets `AbigentApp` and `abigent-diagnostics`, and their matching test targets. Define models as `Sendable`, `Codable`, and `Equatable`. Define this connector API exactly:

```swift
public protocol AgentConnector: Sendable {
    var kind: AgentKind { get }
    func connect() async throws
    func disconnect() async
    func initialSnapshot() async throws -> [AgentTask]
    func events() async -> AsyncStream<AgentEvent>
    func respond(taskID: String, requestID: String, response: UserResponse) async throws
    func cancel(taskID: String) async throws
    func continueTask(taskID: String, prompt: String) async throws
    func sourceURL(taskID: String) async -> URL?
}
```

`TaskState` cases are `discovered`, `working`, `needsInput`, `completed`, `failed`, `cancelled`, and `connectionUnknown`. `AgentEvent` cases are `snapshot(AgentTask)`, `stateChanged(id:state:updatedAt:)`, `attention(id:request:)`, `result(id:result:)`, and `connectionChanged(ConnectionState)`.

- [ ] **Step 4: Run all model tests**

Run: `swift test --filter AgentModelsTests`

Expected: PASS with one test and no Swift concurrency warnings.

- [ ] **Step 5: Commit the contract**

```bash
git add Package.swift Sources/AbigentCore Tests/AbigentCoreTests
git commit -m "feat: define agent task contract"
```

### Task 2: Implement deterministic task reduction and notification policy

**Files:**
- Create: `Sources/AbigentCore/TaskReducer.swift`
- Create: `Sources/AbigentCore/NotificationPolicy.swift`
- Test: `Tests/AbigentCoreTests/TaskReducerTests.swift`
- Test: `Tests/AbigentCoreTests/NotificationPolicyTests.swift`

**Interfaces:**
- Consumes: `AgentTask` and `AgentEvent` from Task 1.
- Produces: `TaskReducer.reduce(current:event:) -> AgentTask` and `NotificationPolicy.decision(previous:current:) -> NotificationDecision`.

- [ ] **Step 1: Write reducer tests for stale and terminal events**

```swift
func testOlderEventCannotReplaceNewerState() throws {
    let current = Fixtures.task(state: .completed, updatedAt: 20)
    let event = AgentEvent.stateChanged(id: current.id, state: .working, updatedAt: Date(timeIntervalSince1970: 10))
    XCTAssertEqual(try TaskReducer.reduce(current: current, event: event), current)
}

func testAttentionEventStoresRequestAndMovesToNeedsInput() throws {
    let current = Fixtures.task(state: .working, updatedAt: 10)
    let request = AttentionRequest(id: "approval-1", title: "Run tests?", body: nil, choices: [.init(id: "yes", label: "Allow")])
    let next = try TaskReducer.reduce(current: current, event: .attention(id: current.id, request: request))
    XCTAssertEqual(next.state, .needsInput)
    XCTAssertEqual(next.attentionRequest, request)
}
```

- [ ] **Step 2: Verify reducer tests fail**

Run: `swift test --filter TaskReducerTests`

Expected: FAIL because `TaskReducer` is undefined.

- [ ] **Step 3: Implement the pure reducer**

Implement one exhaustive switch over `AgentEvent`. Reject an event whose ID differs from `current.id`; ignore dated state events older than `updatedAt`; clear `attentionRequest` when returning to `working`; preserve result data on connection changes; never transform `connectionUnknown` into a terminal state.

- [ ] **Step 4: Write notification-policy tests**

```swift
func testWorkingNeverNotifies() {
    XCTAssertEqual(NotificationPolicy.decision(previous: .discovered, current: .working), .none)
}

func testAttentionAndCompletionNotifyOnceOnEntry() {
    XCTAssertEqual(NotificationPolicy.decision(previous: .working, current: .needsInput), .attention)
    XCTAssertEqual(NotificationPolicy.decision(previous: .needsInput, current: .needsInput), .none)
    XCTAssertEqual(NotificationPolicy.decision(previous: .working, current: .completed), .completed)
}
```

- [ ] **Step 5: Implement and verify notification policy**

Implement `.attention`, `.completed`, and `.failed` only when entering those states from a different state; return `.none` for muted tasks and every other transition.

Run: `swift test --filter 'TaskReducerTests|NotificationPolicyTests'`

Expected: PASS.

- [ ] **Step 6: Commit the core behavior**

```bash
git add Sources/AbigentCore Tests/AbigentCoreTests
git commit -m "feat: reduce task events and notifications"
```

### Task 3: Build and test the Codex JSON-RPC transport

**Files:**
- Create: `Sources/AbigentCodex/JSONValue.swift`
- Create: `Sources/AbigentCodex/JSONRPCMessage.swift`
- Create: `Sources/AbigentCodex/CodexProcessTransport.swift`
- Test: `Tests/AbigentCodexTests/CodexProcessTransportTests.swift`
- Create: `Fixtures/Codex/initialize-response.jsonl`

**Interfaces:**
- Produces: actor `CodexProcessTransport` with `start()`, `send(method:params:)`, `messages()`, and `stop()`.
- Consumes: local executable `codex app-server proxy` by default; tests inject `/bin/sh` and fixture output.

- [ ] **Step 1: Add a failing framing test**

```swift
func testTransportDecodesOneJSONRPCObjectPerLine() async throws {
    let transport = CodexProcessTransport(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", "printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}'"]
    )
    try await transport.start()
    var iterator = await transport.messages().makeAsyncIterator()
    let message = await iterator.next()
    XCTAssertEqual(message?.id, .integer(1))
    await transport.stop()
}
```

- [ ] **Step 2: Verify the transport test fails**

Run: `swift test --filter CodexProcessTransportTests`

Expected: FAIL because the transport types are undefined.

- [ ] **Step 3: Implement newline-delimited JSON-RPC transport**

Use `Process`, `Pipe`, `FileHandle.bytes.lines`, and an actor-owned request table. Encode requests as one compact JSON object followed by `\n`. Route responses by request ID, forward notifications and server requests through `AsyncStream`, treat stderr as diagnostic text only, and fail every pending continuation when the child exits. Do not log raw params or results.

- [ ] **Step 4: Verify clean shutdown and malformed-line behavior**

Add tests proving that malformed lines emit a redacted `.protocolError`, process exit finishes the stream, and calling `stop()` twice is safe.

Run: `swift test --filter CodexProcessTransportTests`

Expected: PASS with four tests and no leaked child process.

- [ ] **Step 5: Commit transport**

```bash
git add Sources/AbigentCodex Tests/AbigentCodexTests Fixtures/Codex
git commit -m "feat: add Codex JSON-RPC transport"
```

### Task 4: Map Codex threads, turns, approvals, and results

**Files:**
- Create: `Sources/AbigentCodex/CodexProtocol.swift`
- Create: `Sources/AbigentCodex/CodexMapper.swift`
- Create: `Sources/AbigentCodex/CodexConnector.swift`
- Create: `Fixtures/Codex/thread-list-response.json`
- Create: `Fixtures/Codex/task-events.jsonl`
- Test: `Tests/AbigentCodexTests/CodexMapperTests.swift`
- Test: `Tests/AbigentCodexTests/CodexConnectorTests.swift`

**Interfaces:**
- Consumes: `AgentConnector` and `CodexProcessTransport`.
- Produces: `CodexConnector` implementing the complete Task 1 protocol.

- [ ] **Step 1: Generate and inspect the installed protocol schema**

Run:

```bash
schema_dir=$(mktemp -d /tmp/abigent-schema.XXXXXX)
codex app-server generate-json-schema --experimental --out "$schema_dir"
rg -n 'thread/list|thread/read|turn/start|turn/completed|item/completed' "$schema_dir/ClientRequest.json" "$schema_dir/ServerNotification.json"
```

Expected: schema contains `thread/list`, `thread/read`, `turn/start`, `turn/completed`, and `item/completed`. Record the installed CLI version and SHA-256 of `codex_app_server_protocol.v2.schemas.json` in `docs/verification/codex-schema.md`; do not commit the full generated schema.

- [ ] **Step 2: Add synthetic fixture mapping tests**

Tests must prove: a running turn maps to `.working`; a server approval request maps to `.needsInput` with its opaque request ID; a completed turn maps to `.completed` or `.failed` from its explicit status; changed files and tests remain absent unless present in protocol data; thread identity is `codex:<threadID>`.

- [ ] **Step 3: Implement protocol envelopes and mapper**

Decode only fields required by Abigent and retain unknown JSON values. Use `thread/list` for snapshots, `thread/read` with turns for details, `turn/started` and `turn/completed` for lifecycle, `item/completed` for explicit result items, and the typed server request method plus JSON-RPC request ID for approvals. Unsupported event methods are ignored with a redacted diagnostic.

- [ ] **Step 4: Add connector request tests with a fake transport**

Verify initialization order is `initialize` request then `initialized` notification then `thread/list`; verify `respond` returns the correct response object for the original server request ID; verify `continueTask` uses `turn/start`; verify `cancel` uses `turn/interrupt`; verify transport failure emits `connectionUnknown` without synthesizing completion.

- [ ] **Step 5: Implement connector and run tests**

Run: `swift test --filter AbigentCodexTests`

Expected: PASS; fixture data contains no real prompts, file paths, tokens, or account identifiers.

- [ ] **Step 6: Commit Codex mapping**

```bash
git add Sources/AbigentCodex Tests/AbigentCodexTests Fixtures/Codex docs/verification/codex-schema.md
git commit -m "feat: map Codex tasks to agent events"
```

### Task 5: Prove the live Codex tracer bullet

**Files:**
- Create: `Sources/AbigentDiagnostics/main.swift`
- Create: `docs/verification/codex-live-check.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: `CodexConnector`.
- Produces: `abigent-diagnostics list`, `watch`, and `doctor` commands used to verify the installed Codex app without UI code.

- [ ] **Step 1: Add diagnostics argument-parser tests without a dependency**

Test that `[]` and unknown commands return usage exit code 64, `doctor` runs only version/connectivity checks, `list` prints redacted task IDs and states, and `watch --seconds 5` stops after its deadline.

- [ ] **Step 2: Implement diagnostics commands**

Output one JSON object per line with keys `timestamp`, `event`, `taskIDHash`, `state`, and `detail`. Hash source task IDs with CryptoKit SHA-256 and never print prompt, response, repository path, account, or token content.

- [ ] **Step 3: Run the live read-only checks**

Run:

```bash
swift run abigent-diagnostics doctor
swift run abigent-diagnostics list
swift run abigent-diagnostics watch --seconds 30
```

Expected: doctor reports compatible local CLI/app-server; list discovers current Codex desktop threads or records a precise unsupported result; watch receives lifecycle events without changing any task.

- [ ] **Step 4: Run a user-approved live reply check**

Create a disposable Codex task that asks one harmless multiple-choice question. Use Abigent diagnostics to deliver the selected response. Do not approve commands, network, file writes, or sandbox escalation during this check.

Expected: the same Codex task leaves `needsInput`, resumes, and reaches an explicit terminal state.

- [ ] **Step 5: Record the gate decision**

In `docs/verification/codex-live-check.md`, record versions, commands, redacted outcomes for snapshot/events/result/reply/open-in-source, and one of: `GO_APP_SERVER`, `GO_WITH_LIMITED_ACCESSIBILITY_FALLBACK`, or `STOP_PROTOCOL_UNSUPPORTED`. A stop decision blocks Tasks 6–9 until the design is revised with the user.

- [ ] **Step 6: Commit the verified tracer bullet**

```bash
git add Sources/AbigentDiagnostics Tests README.md docs/verification/codex-live-check.md
git commit -m "test: verify live Codex task round trip"
```

### Task 5A: Add the explicitly authorized Accessibility fallback when required

Run this task only when Task 5 records `GO_WITH_LIMITED_ACCESSIBILITY_FALLBACK`. Skip it entirely for `GO_APP_SERVER`; stop for `STOP_PROTOCOL_UNSUPPORTED`.

**Files:**
- Create: `Sources/AbigentCodex/Accessibility/AccessibilityAuthorizer.swift`
- Create: `Sources/AbigentCodex/Accessibility/CodexAccessibilityFallback.swift`
- Test: `Tests/AbigentCodexTests/CodexAccessibilityFallbackTests.swift`
- Modify: `docs/verification/codex-live-check.md`

**Interfaces:**
- Consumes: a precise missing capability named in the Task 5 gate record.
- Produces: `CodexAccessibilityFallback` implementing only that capability; it cannot become the primary snapshot or lifecycle source.

- [ ] **Step 1: Add authorization-boundary tests**

Use an injected `AccessibilityAuthorizing` fake. Prove no AX API is called while preference is off, denial returns `.permissionDenied` without repeated prompts, the fallback rejects task IDs not resolved from the live Codex process, and all unsupported actions return `.unsupported`.

- [ ] **Step 2: Implement the narrow fallback**

Use `AXIsProcessTrustedWithOptions` only after the user enables the setting. Address Codex by bundle identifier `com.openai.codex`; resolve windows and controls by accessibility roles and labels, never screen coordinates or pixel colors. Implement only the failed Task 5 capability and keep App Server as the source of task identity and confirmed lifecycle state.

- [ ] **Step 3: Verify permission-off, denied, and granted states**

Run: `swift test --filter CodexAccessibilityFallbackTests`

Expected: PASS without displaying a real system permission dialog. Then perform one manual granted-permission check and append redacted evidence to `docs/verification/codex-live-check.md`.

- [ ] **Step 4: Commit the bounded fallback**

```bash
git add Sources/AbigentCodex/Accessibility Tests/AbigentCodexTests docs/verification/codex-live-check.md
git commit -m "feat: add bounded Codex accessibility fallback"
```

### Task 6: Add local persistence, reconciliation, and notification delivery

**Files:**
- Create: `Sources/AbigentPersistence/SQLiteDatabase.swift`
- Create: `Sources/AbigentPersistence/TaskRepository.swift`
- Create: `Sources/AbigentCore/TaskCoordinator.swift`
- Create: `Sources/AbigentApp/Notifications/NotificationCoordinator.swift`
- Test: `Tests/AbigentPersistenceTests/TaskRepositoryTests.swift`
- Test: `Tests/AbigentCoreTests/TaskCoordinatorTests.swift`

**Interfaces:**
- Consumes: connector snapshots/events and `NotificationPolicy`.
- Produces: `TaskRepository`, observable `TaskCoordinator`, and system notification intents for the UI.

- [ ] **Step 1: Add repository migration and round-trip tests**

Use a temporary SQLite file. Prove schema version 1 creates `tasks`, `attention_requests`, `results`, and `notification_receipts`; an upsert preserves source identity; `clearAll()` removes business rows; reopening the database returns the last confirmed state.

- [ ] **Step 2: Implement parameterized SQLite access**

Use the system `SQLite3` module, prepared statements only, WAL mode, foreign keys, and transactions for a task plus child records. Store structured data as Codable JSON blobs only after redaction. On corruption, move the file to a timestamped `.corrupt` sibling and create a new database.

- [ ] **Step 3: Add reconciliation and deduplication tests**

Prove that a newer snapshot wins, absent active tasks become `connectionUnknown` rather than completed, duplicate events do not duplicate receipts, reconnecting to an already completed task does not notify twice, and muted tasks never notify.

- [ ] **Step 4: Implement coordinator and system notifications**

`TaskCoordinator` owns connector consumption and repository writes on one actor. `NotificationCoordinator` requests permission only when the user enables notifications and uses stable identifiers `<task-id>:<state>:<updated-at>`. Notification actions are `OPEN`, `ALLOW`, and `DENY`; approval actions route through `TaskCoordinator` and still show task title before submission in the app.

- [ ] **Step 5: Run persistence and core suites**

Run: `swift test --filter 'AbigentPersistenceTests|TaskCoordinatorTests|NotificationPolicyTests'`

Expected: PASS, including reconnect and corruption cases.

- [ ] **Step 6: Commit local state handling**

```bash
git add Sources/AbigentPersistence Sources/AbigentCore Sources/AbigentApp/Notifications Tests
git commit -m "feat: persist and reconcile local tasks"
```

### Task 7: Build the menu-bar task experience and reply flow

**Files:**
- Create: `Sources/AbigentApp/AbigentApp.swift`
- Create: `Sources/AbigentApp/AppModel.swift`
- Create: `Sources/AbigentApp/MenuBar/MenuBarContentView.swift`
- Create: `Sources/AbigentApp/MenuBar/TaskRowView.swift`
- Create: `Sources/AbigentApp/MenuBar/TaskDetailView.swift`
- Create: `Sources/AbigentApp/MenuBar/AttentionCardView.swift`
- Create: `Sources/AbigentApp/MenuBar/ResultCardView.swift`
- Create: `Sources/AbigentApp/Settings/SettingsView.swift`
- Test: `Tests/AbigentAppTests/AppModelTests.swift`

**Interfaces:**
- Consumes: `TaskCoordinator` task stream and commands.
- Produces: native `MenuBarExtra`, attention replies, result details, task continuation, cancellation, settings, and source opening.

- [ ] **Step 1: Add app-model sorting and action tests**

Prove ordering is attention first, working second, terminal newest-first; only explicit connector data appears in result fields; failed replies retain draft text and expose retry; cancel requires confirmation; open-source gracefully disables when URL is absent.

- [ ] **Step 2: Implement `AppModel` on `@MainActor`**

Expose immutable sections `[AttentionTask]`, `[ActiveTask]`, and `[RecentTask]`. Every user command enters a per-task `ActionState` of idle/sending/failed and calls `TaskCoordinator`; successful sends clear drafts only after connector acknowledgement.

- [ ] **Step 3: Build focused SwiftUI views**

Use a 380-point menu panel. `AttentionCardView` displays exact source task, request body, choices, and text field. `ResultCardView` labels missing tests as “未运行/未提供”. `TaskDetailView` exposes “查看详情”, “继续任务”, “取消任务”, and “打开 Codex” based on actual connector capabilities.

- [ ] **Step 4: Add settings and permissions copy**

Settings include launch at login, show pet, pet always on top, notifications, sound, active display, and clear local history. Accessibility fallback is shown as off with an explanation and is not enabled by this task.

- [ ] **Step 5: Build and run non-UI tests**

Run: `swift test --filter AbigentAppTests`

Expected: PASS. Then, after full Xcode is selected, run `swift run AbigentApp` and manually verify the menu extra with fixture mode before live Codex mode.

- [ ] **Step 6: Commit the menu-bar slice**

```bash
git add Sources/AbigentApp Tests/AbigentAppTests
git commit -m "feat: add menu bar task controls"
```

### Task 8: Add the Abigent desktop pet and reviewed art states

**Files:**
- Create: `Sources/AbigentApp/Pet/PetWindowController.swift`
- Create: `Sources/AbigentApp/Pet/PetView.swift`
- Create: `Sources/AbigentApp/Pet/PetAnimationState.swift`
- Create: `Sources/AbigentApp/Pet/PetPositionStore.swift`
- Create: `Resources/Pet/README.md`
- Create: `Resources/Pet/idle.imageset/*`
- Create: `Resources/Pet/working.imageset/*`
- Create: `Resources/Pet/needs-input.imageset/*`
- Create: `Resources/Pet/completed.imageset/*`
- Create: `Resources/Pet/disconnected.imageset/*`
- Test: `Tests/AbigentAppTests/PetAnimationStateTests.swift`

**Interfaces:**
- Consumes: aggregate task state from `AppModel` and user pet preferences.
- Produces: draggable transparent AppKit window and accessible state animation.

- [ ] **Step 1: Add deterministic aggregate-state tests**

Prove priority is `needsInput > disconnected > working > completed pulse > idle`; completion pulse expires once; hiding the pet does not stop connector consumption or the menu-bar app.

- [ ] **Step 2: Implement the AppKit window**

Use a borderless transparent `NSPanel`, `isFloatingPanel = true`, `hidesOnDeactivate = false`, no shadow rectangle, and a SwiftUI hosting view. Clamp saved positions to the visible frame of an attached display. Support drag, secondary-click menu, and optional click-through while idle.

- [ ] **Step 3: Create the half-realistic art set from the supplied cat reference**

Use the provided cat photograph only as the approved visual reference. Produce transparent-background frames preserving tall ears, golden eyes, warm taupe coat, and realistic proportions. Create idle breathing/tail, working-at-small-screen, raised-paw orange attention, stretch completion, and neutral disconnected states. Review rendered assets with the user before replacing any provisional vector silhouette.

- [ ] **Step 4: Drive art from state without distracting loops**

Idle and working animations loop slowly; attention uses a one-time raised-paw motion plus static orange badge; completion plays once then returns to idle; reduced-motion preference switches all states to still frames.

- [ ] **Step 5: Verify desktop behaviors with full Xcode**

Check one and multiple displays, Spaces, full-screen apps, sleep/wake, display removal, menu-bar auto-hide, always-on-top off/on, reduced motion, and pet hidden. Capture screenshots in `docs/verification/pet-ui/`.

- [ ] **Step 6: Commit the pet slice**

```bash
git add Sources/AbigentApp/Pet Resources/Pet Tests/AbigentAppTests docs/verification/pet-ui
git commit -m "feat: add Abigent desktop pet"
```

### Task 9: Harden, package, and document the product

**Files:**
- Create: `Scripts/build-app.sh`
- Create: `Scripts/create-dmg.sh`
- Create: `Resources/Info.plist`
- Create: `Resources/Abigent.entitlements`
- Create: `docs/INSTALL.md`
- Create: `docs/PRIVACY.md`
- Create: `docs/IMPLEMENTATION.md`
- Create: `docs/verification/release-checklist.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: all production targets and resources.
- Produces: `dist/Abigent.app`, `dist/Abigent.dmg`, install/privacy docs, and the user-requested implementation summary.

- [ ] **Step 1: Add a release smoke test script**

The script must fail unless the app has identifier `com.abigent.desktop`, minimum macOS 14.0, no unexpected network client entitlement, bundled pet resources, executable architectures containing `arm64`, and a successful `codesign --verify --deep --strict` result.

- [ ] **Step 2: Implement reproducible local app bundling**

`build-app.sh` runs release tests, builds the Swift executable, creates the `.app` directory structure, copies resources and Info.plist, and signs ad hoc when `ABIGENT_SIGNING_IDENTITY` is absent. It never reads credentials from project files.

- [ ] **Step 3: Implement DMG creation**

`create-dmg.sh` requires an explicit built app path, creates a temporary staging directory with `Abigent.app` and an Applications symlink, writes `dist/Abigent.dmg`, verifies the mounted contents, then detaches. It must not overwrite a non-Abigent path or delete outside its validated temporary directory.

- [ ] **Step 4: Add distribution signing path**

When `ABIGENT_SIGNING_IDENTITY` and an externally configured notarization keychain profile are present, sign hardened runtime, submit with `xcrun notarytool`, staple, and verify Gatekeeper. Without credentials, produce an ad-hoc development DMG and label it clearly as not ready for external distribution.

- [ ] **Step 5: Write the final implementation handoff**

`docs/IMPLEMENTATION.md` must explain delivered capabilities, module boundaries, Codex discovery, event mapping, reply routing, persistence, notification rules, pet state animation, permissions, recovery, test evidence, packaging, local data removal, known limits, protocol compatibility, and the exact `TraeCNConnector` extension seam.

- [ ] **Step 6: Run the complete release gate**

Run:

```bash
swift test
Scripts/build-app.sh
Scripts/create-dmg.sh dist/Abigent.app
codesign --verify --deep --strict dist/Abigent.app
spctl --assess --type execute --verbose dist/Abigent.app || true
```

Expected: all tests pass; app and DMG exist; code-sign verification passes; Gatekeeper passes for Developer ID builds or is documented as expected failure for ad-hoc builds.

- [ ] **Step 7: Commit the release candidate**

```bash
git add Scripts Resources README.md docs
git commit -m "release: package Abigent MVP"
```

## Plan Completion Criteria

The MVP is complete only when Task 5 records a non-stop protocol decision, all automated tests pass, the live Codex snapshot/event/reply/result loop is evidenced, the pet and menu bar survive the manual macOS matrix, no Abigent-owned server or hidden telemetry exists, and an installable DMG plus `docs/IMPLEMENTATION.md` are delivered. If full Xcode or Developer ID credentials remain unavailable, the development app and ad-hoc DMG may be delivered, but external-distribution signing and notarization must be reported as incomplete rather than implied complete.
