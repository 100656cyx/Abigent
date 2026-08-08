# Abigent Hook Realtime Sync and Hover Results Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Hook-driven Codex lifecycle synchronization, local result extraction, and a pet hover card that shows the latest Agent conclusion and expands to the full response.

**Architecture:** Codex invokes a small `abigent-hook` relay for registered lifecycle events. The relay sends versioned NDJSON to a current-user Unix socket owned by Abigent; a normalizer converts envelopes to the existing unified task model, while the existing App Server and session watcher remain recovery channels. On Stop, a bounded incremental session reader extracts the final assistant response and publishes it to the menu bar and desktop pet hover card.

**Tech Stack:** Swift 6.1, SwiftUI, AppKit, Foundation Unix sockets, SQLite3, SwiftPM, Codex `hooks.json`, macOS 14+

## Global Constraints

- macOS 14.0 or newer; Apple Silicon release package for the current MVP.
- All Abigent data and IPC remain local; do not add network clients, telemetry, accounts, or remote control.
- Preserve every non-Abigent entry in `~/.codex/hooks.json`, including Flux Island entries.
- Manage only entries containing the stable marker `com.abigent.desktop`.
- Hook relay failure must not block or fail the Codex task.
- Never auto-approve a permission request.
- Event priority is Hook > App Server > session-log recovery > Accessibility fallback.
- Missing source fields stay unknown; do not infer file changes, tests, progress, or results from prose alone.
- Trae CN is not implemented in this plan, but Hook envelopes and adapter boundaries must remain Agent-neutral.
- Current Command Line Tools cannot execute XCTest; author deterministic XCTest sources, compile every production target, and run XCTest when full Xcode becomes available.

---

### Task 1: Add Event Provenance and Result Timing to the Unified Model

**Files:**
- Modify: `AppSources/AbigentCore/AgentModels.swift`
- Modify: `AppSources/AbigentCore/TaskReducer.swift`
- Test: `Tests/AbigentCoreTests/TaskReducerTests.swift`

**Interfaces:**
- Produces: `EventProvenance`, `ObservedAgentEvent`, and `TaskResult.returnedAt: Date?`.
- Consumes: existing `AgentEvent`, `AgentTask`, `TaskResult`, and `GlobalTaskID`.

- [ ] **Step 1: Write failing precedence and result-time tests**

Add tests proving that a Hook event beats a later recovery event, duplicate Hook events are idempotent, and `TaskResult.returnedAt` survives Codable round-tripping:

```swift
func testHookEventWinsOverRecoveryEvent() throws {
    let current = fixture(state: .working, observedAt: date(20), provenance: .hook)
    let stale = observed(.stateChanged(id: current.id, state: .discovered, updatedAt: date(30)), .sessionRecovery)
    XCTAssertEqual(try TaskReducer.reduce(current: current, observed: stale).state, .working)
}

func testResultReturnTimeRoundTrips() throws {
    let result = TaskResult(summary: "Done", changedFiles: nil, tests: nil, detail: "Done", returnedAt: date(42))
    XCTAssertEqual(try JSONDecoder().decode(TaskResult.self, from: JSONEncoder().encode(result)), result)
}
```

- [ ] **Step 2: Run the focused test target and record the expected toolchain limitation**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
CLANG_MODULE_CACHE_PATH=/tmp/abigent-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/abigent-swiftpm-cache \
swift test --disable-sandbox --scratch-path /tmp/abigent-build --filter TaskReducerTests
```

Expected on the current machine: test discovery stops because XCTest is absent. Confirm the production `AbigentCore` target still compiles after Step 4.

- [ ] **Step 3: Add the provenance types and backward-compatible Codable fields**

Implement:

```swift
public enum EventProvenance: Int, Codable, Sendable, Comparable {
    case accessibilityFallback = 0, sessionRecovery = 1, appServer = 2, hook = 3
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct ObservedAgentEvent: Codable, Sendable, Equatable {
    public let event: AgentEvent
    public let provenance: EventProvenance
    public let observedAt: Date
}
```

Add optional provenance/observation metadata to `AgentTask`, and add `returnedAt: Date? = nil` to `TaskResult` with an explicit initializer default so existing call sites and stored JSON remain readable.

- [ ] **Step 4: Extend reducer precedence without changing identity checks**

Add `reduce(current:observed:)`; reject a lower-priority event when it would reverse a higher-priority state, and retain the existing `reduce(current:event:)` as an App Server compatibility wrapper.

- [ ] **Step 5: Compile production targets**

Run the SDK command above with `swift build ... --product Abigent`. Expected: `Build complete`.

- [ ] **Step 6: Commit**

```bash
git add AppSources/AbigentCore Tests/AbigentCoreTests
git commit -m "feat: track agent event provenance"
```

---

### Task 2: Implement Safe Codex Hook Configuration Merging

**Files:**
- Create: `AppSources/AbigentCodex/Hooks/CodexHookConfiguration.swift`
- Create: `AppSources/AbigentCodex/Hooks/CodexHookInstaller.swift`
- Test: `Tests/AbigentCodexTests/CodexHookInstallerTests.swift`

**Interfaces:**
- Produces: `CodexHookInstaller.inspect()`, `install(relayURL:)`, and `uninstall()` returning `HookInstallationStatus`.
- Consumes: a hooks file URL and backup/receipt URLs supplied by the app.

- [ ] **Step 1: Write failing fixture tests**

Cover a missing file, a Flux-only file, an existing Abigent entry, malformed JSON, upgrade, and uninstall. The coexistence assertion must compare the third-party JSON subtree byte-for-byte after canonical JSON encoding.

```swift
func testInstallPreservesFluxEntry() throws {
    let installer = fixtureInstaller(json: fluxFixture)
    try installer.install(relayURL: URL(fileURLWithPath: "/Applications/Abigent.app/Contents/Helpers/abigent-hook"))
    XCTAssertEqual(try thirdPartyEntries(after: installer), thirdPartyEntries(in: fluxFixture))
    XCTAssertEqual(try abigentEvents(after: installer), Set(CodexHookEvent.allCases))
}
```

- [ ] **Step 2: Verify the tests fail for missing types**

Run the focused test command from Task 1 with `--filter CodexHookInstallerTests`; expect missing-type compile failures when XCTest is available.

- [ ] **Step 3: Implement typed configuration and stable ownership marker**

Define the exact event set:

```swift
public enum CodexHookEvent: String, CaseIterable, Codable {
    case sessionStart = "SessionStart"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case permissionRequest = "PermissionRequest"
    case postToolUse = "PostToolUse"
    case stop = "Stop"
    case subagentStop = "SubagentStop"
}
```

Generate commands that quote the relay path safely and include `--marker com.abigent.desktop --source codex --event <event>`.

- [ ] **Step 4: Implement atomic merge, backup, receipt, and owned uninstall**

Read before writing; reject malformed roots; retain unknown JSON fields; write a sibling temporary file, validate it, then replace atomically. Store a receipt containing schema version, installed event names, relay path, and installation time. Uninstall only commands containing the exact marker.

- [ ] **Step 5: Compile and inspect a temporary fixture**

Use a temporary hooks path under `/tmp`, install next to a Flux fixture, and verify both command groups exist. Never write the real `~/.codex/hooks.json` in automated tests.

- [ ] **Step 6: Commit**

```bash
git add AppSources/AbigentCodex/Hooks Tests/AbigentCodexTests/CodexHookInstallerTests.swift
git commit -m "feat: merge Abigent Codex hooks safely"
```

---

### Task 3: Build the Non-Blocking Hook Relay and Local Socket Server

**Files:**
- Modify: `Package.swift`
- Create: `AppSources/AbigentHookRelay/main.swift`
- Create: `AppSources/AbigentHooks/HookEnvelope.swift`
- Create: `AppSources/AbigentHooks/HookSocketServer.swift`
- Test: `Tests/AbigentHooksTests/HookSocketServerTests.swift`

**Interfaces:**
- Produces: executable `abigent-hook`, `HookEnvelope`, and `HookSocketServer.events() -> AsyncStream<HookEnvelope>`.
- Consumes: JSON on stdin, CLI source/event/marker parameters, and a socket path from `ABIGENT_SOCKET_PATH` or the standard Application Support location.

- [ ] **Step 1: Add failing framing and failure-isolation tests**

Test split writes, multiple newline-delimited envelopes, oversized messages, malformed JSON, socket removal on clean stop, and relay exit code zero when the server is absent.

- [ ] **Step 2: Add focused SwiftPM targets**

Create `AbigentHooks` library, `AbigentHookRelay` executable product `abigent-hook`, and `AbigentHooksTests` target without third-party dependencies.

- [ ] **Step 3: Implement the versioned envelope**

```swift
public struct HookEnvelope: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let source: AgentKind
    public let event: String
    public let sessionID: String?
    public let observedAt: Date
    public let payload: JSONValue
}
```

Move `JSONValue` to `AbigentCore` so the Agent-neutral Hook module does not depend on `AbigentCodex`.

- [ ] **Step 4: Implement current-user Unix socket ownership and NDJSON framing**

Create the parent directory with `0700`, bind the socket with `0600`, reject peers whose effective UID differs where peer credentials are available, cap each line at 1 MiB, and delete only the exact socket file owned by the server.

- [ ] **Step 5: Implement the relay's fast-fail behavior**

Read stdin with an upper bound, wrap the payload, connect with a short timeout, write one NDJSON line, and exit `0` even when Abigent is not running. Emit diagnostics only to stderr when `ABIGENT_HOOK_DEBUG=1`.

- [ ] **Step 6: Compile and run a local socket smoke test under `/tmp`**

Expected: one fixture event is decoded; stopping the server removes the socket; invoking relay without a server returns in under one second.

- [ ] **Step 7: Commit**

```bash
git add Package.swift AppSources/AbigentCore AppSources/AbigentHooks AppSources/AbigentHookRelay Tests/AbigentHooksTests
git commit -m "feat: add local Hook event bridge"
```

---

### Task 4: Normalize Codex Hooks into Unified Agent Events

**Files:**
- Create: `AppSources/AbigentCodex/Hooks/CodexHookNormalizer.swift`
- Create: `AppSources/AbigentCodex/Hooks/CodexHookPayload.swift`
- Test: `Tests/AbigentCodexTests/CodexHookNormalizerTests.swift`

**Interfaces:**
- Produces: `CodexHookNormalizer.normalize(_:) -> [ObservedAgentEvent]` and a session-to-task identity cache.
- Consumes: `HookEnvelope` from Task 3.

- [ ] **Step 1: Write one failing test per registered Hook event**

Assert exact states and provenance. `PermissionRequest` produces `.attention`; `SubagentStop` must not complete the parent; unknown events produce an empty array.

- [ ] **Step 2: Implement tolerant payload decoding**

Decode known aliases for session/thread ID, cwd, tool name, prompt and permission options while retaining the raw payload. Do not fail the entire envelope because an optional field is absent.

- [ ] **Step 3: Implement deterministic event mapping**

Map `UserPromptSubmit` to working, `PermissionRequest` to needs input, and `Stop` to completion plus a pending-result marker. Use Hook observation time for reducer ordering.

- [ ] **Step 4: Add bounded identity buffering**

Buffer unassociated events for at most 30 seconds and 100 envelopes; replay after SessionStart/App Server identifies the task; discard expired entries with a local diagnostic.

- [ ] **Step 5: Compile and commit**

```bash
git add AppSources/AbigentCodex/Hooks Tests/AbigentCodexTests/CodexHookNormalizerTests.swift
git commit -m "feat: normalize Codex Hook events"
```

---

### Task 5: Extract the Final Codex Response Incrementally

**Files:**
- Create: `AppSources/AbigentCodex/Results/CodexResultExtractor.swift`
- Create: `AppSources/AbigentCodex/Results/SessionOffsetStore.swift`
- Modify: `AppSources/AbigentPersistence/TaskRepository.swift`
- Test: `Tests/AbigentCodexTests/CodexResultExtractorTests.swift`

**Interfaces:**
- Produces: `extract(sessionID:stopObservedAt:) async throws -> TaskResult` and persisted per-session byte offsets.
- Consumes: Codex session JSONL and Stop events from Task 4.

- [ ] **Step 1: Write fixture tests for result extraction**

Fixtures must cover a normal assistant message, multiline Chinese output, delayed final write, no assistant message, explicit file-change events, duplicate paths, and explicit test exit data.

- [ ] **Step 2: Implement safe session lookup and offset storage**

Resolve files by validated UUID suffix under `~/.codex/sessions`; never accept path components from Hook payload. Store committed byte offsets in SQLite only after decoding complete lines.

- [ ] **Step 3: Implement bounded incremental parsing**

Read from the last committed offset, retain a partial final line, select the last closed turn, and build:

```swift
TaskResult(
    summary: firstNonEmptyParagraph.map { String($0.prefix(160)) },
    changedFiles: explicitPaths.isEmpty ? nil : orderedUnique(explicitPaths),
    tests: explicitTestSummary,
    detail: finalAssistantText,
    returnedAt: stopObservedAt
)
```

- [ ] **Step 4: Add delayed-write retry policy**

Retry after 100, 250, 500, and 1000 ms; publish completion immediately and add the result when available. After the final retry return an explicit `resultNotYetAvailable` error rather than invented content.

- [ ] **Step 5: Compile and commit**

```bash
git add AppSources/AbigentCodex/Results AppSources/AbigentPersistence Tests/AbigentCodexTests/CodexResultExtractorTests.swift
git commit -m "feat: extract Codex final responses"
```

---

### Task 6: Integrate Hook Events with Runtime and Persistence

**Files:**
- Modify: `AppSources/AbigentRuntime/TaskCoordinator.swift`
- Create: `AppSources/AbigentRuntime/AgentEventMux.swift`
- Modify: `AppSources/AbigentApp/AppModel.swift`
- Test: `Tests/AbigentRuntimeTests/AgentEventMuxTests.swift`
- Test: `Tests/AbigentRuntimeTests/TaskCoordinatorTests.swift`

**Interfaces:**
- Produces: one ordered `AsyncStream<ObservedAgentEvent>` for TaskCoordinator.
- Consumes: App Server, Hook normalizer, result extractor, session recovery and Accessibility fallback streams.

- [ ] **Step 1: Write failing multiplexing tests**

Cover duplicate Stop events, lower-priority recovery after Hook completion, result arriving after completion, two simultaneous task IDs, and reconnect after Abigent restart.

- [ ] **Step 2: Implement `AgentEventMux`**

Assign provenance at the ingestion boundary, serialize events per `GlobalTaskID`, and use a stable event fingerprint for bounded duplicate suppression.

- [ ] **Step 3: Update TaskCoordinator to consume observed events**

Persist provenance and `returnedAt`; send notifications only for actual state transitions; publish the result update without sending a second completion notification.

- [ ] **Step 4: Start and stop Hook server with AppModel**

Start the socket before connectors, expose `hookConnectionMessage`, and fall back to the existing session watcher if server startup fails.

- [ ] **Step 5: Compile and commit**

```bash
git add AppSources/AbigentRuntime AppSources/AbigentApp/AppModel.swift Tests/AbigentRuntimeTests
git commit -m "feat: merge Hook events into task runtime"
```

---

### Task 7: Add the Pet Hover Summary and Expandable Result Card

**Files:**
- Modify: `Package.swift`
- Create: `AppSources/AbigentApp/Pet/PetResultCard.swift`
- Create: `AppSources/AbigentApp/Pet/PetHoverState.swift`
- Modify: `AppSources/AbigentApp/Pet/PetView.swift`
- Modify: `AppSources/AbigentApp/Pet/PetWindowController.swift`
- Modify: `AppSources/AbigentApp/AppModel.swift`
- Test: `Tests/AbigentAppTests/PetHoverStateTests.swift`

**Interfaces:**
- Produces: `PetHoverState`, task selection policy, transient/fixed card modes, and `PetResultCard`.
- Consumes: published unified tasks and existing pet animation state.

- [ ] **Step 1: Write task-selection and timing tests**

Assert priority `needsInput > working > latest completed > connection issue > idle`, 180 ms entry delay, 250 ms exit grace, pin/unpin, and a completed result with no detail showing “结果同步中”.

Add an `AbigentAppTests` target in `Package.swift` that depends on `AbigentApp`, `AbigentCore`, and `AbigentRuntime` before adding the test file.

- [ ] **Step 2: Implement pure hover state logic**

Keep timers and task selection outside SwiftUI rendering so state transitions are deterministic and testable.

- [ ] **Step 3: Implement the compact card**

Render Agent, project, status, 3–5 line summary, local returned time, explicit file/test badges, “查看完整结果”, and “打开 Codex”. Do not render absent evidence as zero.

- [ ] **Step 4: Implement expanded mode and safe screen placement**

Use a scrollable result body, close control, and a card frame clamped to `NSScreen.visibleFrame`. Keep the pointer inside the combined pet/card hit area so moving to the card does not dismiss it.

- [ ] **Step 5: Verify reduced motion and accessibility labels**

Hover remains functional with Reduce Motion. Add labels for state, summary, return time, expand and close controls.

- [ ] **Step 6: Compile and commit**

```bash
git add Package.swift AppSources/AbigentApp/Pet AppSources/AbigentApp/AppModel.swift Tests/AbigentAppTests
git commit -m "feat: show Agent results beside the pet"
```

---

### Task 8: Add User-Controlled Hook Setup and Privacy Controls

**Files:**
- Modify: `AppSources/AbigentApp/Settings/SettingsView.swift`
- Create: `AppSources/AbigentApp/Settings/HookSetupView.swift`
- Modify: `AppSources/AbigentApp/AppModel.swift`
- Modify: `docs/INSTALL.md`
- Modify: `docs/PRIVACY.md`

**Interfaces:**
- Produces: inspect/enable/repair/disable Hook UI and `showHoverResults` preference.
- Consumes: `CodexHookInstaller` and Hook server connection status.

- [ ] **Step 1: Add settings state and persisted preferences**

Persist Hook enabled receipt state and “悬停显示结果” using `UserDefaults`; derive actual installation health by inspecting the config, never by trusting the preference alone.

- [ ] **Step 2: Implement the setup disclosure**

Before installation show the exact config path, seven event names, local Socket path, coexistence guarantee, and disable behavior. The final enable button is the only action that writes Hook configuration.

- [ ] **Step 3: Implement repair and owned uninstall**

Repair re-merges owned entries; disable removes only marker-owned Abigent commands. Display malformed configuration as a blocking error with no write attempt.

- [ ] **Step 4: Update installation and privacy documentation**

Document local content storage, Hook payload handling, Flux coexistence, the relay's non-blocking behavior, and manual recovery from a malformed hooks file.

- [ ] **Step 5: Compile and commit**

```bash
git add AppSources/AbigentApp/Settings AppSources/AbigentApp/AppModel.swift docs/INSTALL.md docs/PRIVACY.md
git commit -m "feat: add safe Codex Hook setup"
```

---

### Task 9: Package Helpers and Perform Live Coexistence Verification

**Files:**
- Modify: `Scripts/build-app.sh`
- Modify: `Scripts/create-dmg.sh`
- Modify: `Resources/Info.plist`
- Modify: `docs/IMPLEMENTATION.md`
- Modify: `docs/verification/release-checklist.md`
- Create: `docs/verification/hook-live-check.md`

**Interfaces:**
- Produces: signed `Abigent.app` with `Contents/Helpers/abigent-hook` and verified `Abigent.dmg`.
- Consumes: all production targets and the user-approved real Hook installation flow.

- [ ] **Step 1: Package and sign the relay**

Copy the release `abigent-hook` executable to `Contents/Helpers`, sign nested code before signing the outer app, and verify with `codesign --verify --deep --strict`.

- [ ] **Step 2: Build release artifacts**

Run:

```bash
Scripts/build-app.sh
Scripts/create-dmg.sh dist/Abigent.app
```

Expected: valid app signature and `hdiutil verify` success.

- [ ] **Step 3: Inspect existing real Hooks before installation**

Hash/canonicalize the non-Abigent subtrees of `~/.codex/hooks.json`; save only event names and hashes in the verification document, never command arguments or payload content.

- [ ] **Step 4: Enable Abigent Hooks through its UI**

This is a persistent configuration change and must use the approved setup action. After installation, verify Flux Island entries retain identical canonical hashes and all seven Abigent event groups exist once.

- [ ] **Step 5: Run a live Codex tracer task**

Record timestamps for UserPromptSubmit, working UI, Stop, completion UI and extracted result. Success requires each UI transition within 1 second of its Hook receipt and exact final assistant text in the expanded card.

- [ ] **Step 6: Verify permission and coexistence behavior**

Trigger a benign approval request; confirm Abigent shows it but never auto-approves. Disable Abigent Hooks and prove Flux hashes remain unchanged; re-enable for the delivered build only with user approval.

- [ ] **Step 7: Update implementation and verification docs**

Record build, signature, DMG, timing, result extraction, known XCTest limitation, and any remaining Accessibility fallback limitation.

- [ ] **Step 8: Final commit**

```bash
git add Scripts Resources docs
git commit -m "release: package Hook-driven Abigent"
```
