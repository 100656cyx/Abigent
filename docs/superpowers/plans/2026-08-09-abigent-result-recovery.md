# Abigent Codex Final Result Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reliably replace “任务已完成，结果同步中” with the exact final Codex reply after every Stop event.

**Architecture:** A focused actor owns one cancellable recovery task per Codex session. It repeatedly asks the existing result extractor for the latest stopped turn, emits one result on success, and records privacy-safe diagnostics on timeout; AppModel only wires Stop envelopes to this actor.

**Tech Stack:** Swift 6, Swift Concurrency, Foundation, SQLite persistence, macOS 14+, Swift Package Manager.

## Global Constraints

- All processing remains local and must not modify Flux Island or third-party Hook entries.
- Recovery lasts at most 30 seconds and must not block Hook event handling.
- Diagnostic records must not contain prompt or response text.
- Preserve the existing pet UI and notification behavior.
- The current Command Line Tools installation cannot import XCTest; production targets must still compile and link with the macOS 15.4 SDK workaround.

---

### Task 1: Make the Result Extractor Stop-Aware

**Files:**
- Modify: `AppSources/AbigentCodex/Results/CodexResultExtractor.swift`
- Test: `Tests/AbigentCodexTests/CodexResultExtractorTests.swift`

**Interfaces:**
- Consumes: `extract(sessionID:stopObservedAt:) async throws -> TaskResult`
- Produces: the same public signature, with parsing that accepts the latest non-empty `agent_message` after the latest `task_started` when Stop proves the turn has ended.

- [ ] **Step 1: Write failing extractor tests**

Add tests for a complete turn, a Stop-time candidate without `task_complete`, malformed JSON lines, and ensuring a previous turn's message is never selected after a new `task_started`.

- [ ] **Step 2: Verify the tests are discoverable**

Run the production build and attempt the focused XCTest target. Expected: production compilation succeeds; XCTest remains unavailable under Command Line Tools and is recorded as an environment limitation.

- [ ] **Step 3: Implement minimal stop-aware parsing**

Track `lastStart`, `lastComplete`, and the last non-empty message after `lastStart`. Prefer the last message bounded by `lastComplete`; otherwise return the latest post-start message because the caller only invokes extraction after Stop.

- [ ] **Step 4: Rebuild production targets**

Run the macOS 15.4 SDK workaround build. Expected: `Abigent`, `abigent-hook`, and all library targets compile and link.

- [ ] **Step 5: Commit**

```bash
git add AppSources/AbigentCodex/Results/CodexResultExtractor.swift Tests/AbigentCodexTests/CodexResultExtractorTests.swift
git commit -m "fix: extract stopped Codex turn results"
```

### Task 2: Add Durable In-Process Result Recovery

**Files:**
- Create: `AppSources/AbigentApp/Results/CodexResultRecoveryCoordinator.swift`
- Modify: `AppSources/AbigentApp/AppModel.swift`
- Test: `Tests/AbigentAppTests/CodexResultRecoveryCoordinatorTests.swift`

**Interfaces:**
- Consumes: `CodexResultExtractor.extract(sessionID:stopObservedAt:)` and a Stop `HookEnvelope`.
- Produces: `recover(sessionID:stopObservedAt:deliver:)`, with one cancellable task per session and at most one delivered `TaskResult` for each recovery generation.

- [ ] **Step 1: Write failing recovery tests**

Use an injected async extraction closure and zero-duration test schedule. Assert retry-then-success, timeout without delivery, replacement of an older same-session generation, and independent concurrent sessions.

- [ ] **Step 2: Implement the recovery actor**

Create a schedule beginning immediately and backing off within a 30-second deadline. Store tasks by session ID, cancel prior same-session work, remove completed work, and send privacy-safe failures to `Logger` using only error category, session ID, attempt count, and timestamp.

- [ ] **Step 3: Wire Stop handling**

Replace AppModel's one-shot `try? await extractor.extract(...)` block with the recovery coordinator. On success, ingest the existing `.result` event with Hook provenance and the original Stop timestamp.

- [ ] **Step 4: Build and inspect concurrency warnings**

Run the production build with Swift 6 checks. Expected: no actor-isolation or Sendable errors.

- [ ] **Step 5: Commit**

```bash
git add AppSources/AbigentApp/Results AppSources/AbigentApp/AppModel.swift Tests/AbigentAppTests/CodexResultRecoveryCoordinatorTests.swift
git commit -m "fix: recover delayed Codex final results"
```

### Task 3: Package, Install, and Run a Live Stop Test

**Files:**
- Modify: `docs/verification/hook-live-check.md`
- Modify: `docs/verification/release-checklist.md`

**Interfaces:**
- Consumes: the signed Abigent app, installed Hooks, live Codex session JSONL, and local tasks database.
- Produces: an installed release whose hover card contains the exact latest Codex final reply and returned time.

- [ ] **Step 1: Build and package**

Run `Scripts/build-app.sh` with the macOS 15.4 SDK variables, then `Scripts/create-dmg.sh`. Expected: signed app and nested helper validate, and the DMG mounts successfully.

- [ ] **Step 2: Replace the installed app safely**

Quit Abigent, move the previous `/Applications/Abigent.app` to Trash with a timestamped recoverable name, copy the new app into Applications, and launch it. Existing local database and Hook configuration remain untouched.

- [ ] **Step 3: Verify installed runtime**

Check that `~/.abigent/run/bridge.sock` is present with `0600`, seven Abigent Hook entries still exist once each, and the normalized non-Abigent Hook hash remains `83d23361af2d9ada434ce20563e7d7eef4db07646551a8b00f2dccddb16bca59`.

- [ ] **Step 4: Run a real Codex turn**

After a new user prompt completes, confirm the result row contains the exact final `agent_message`, the task is completed with Hook provenance, and hovering the cat shows summary, detail, and returned time instead of the indefinite syncing placeholder.

- [ ] **Step 5: Record and commit verification**

```bash
git add docs/verification/hook-live-check.md docs/verification/release-checklist.md
git commit -m "release: verify Codex result recovery"
```
