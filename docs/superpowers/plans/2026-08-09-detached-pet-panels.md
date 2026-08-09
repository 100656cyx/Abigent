# Detached Pet Panels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the cat's main window frame fixed while task results and controls appear in separately anchored panels.

**Architecture:** `PetView` becomes a fixed-size cat-only view that reports hover. `PetWindowController` owns three panels: the fixed pet panel, a result panel, and a control panel; it centralizes hover timing and anchors auxiliaries without resizing the pet panel.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Package Manager, macOS 14+

## Global Constraints

- Only an explicit primary-button drag on the cat may change the pet panel origin.
- Result and control visibility must never call `setFrame` on the pet panel.
- Keep existing result content, actions, 50%–150% scale range, persistence format, Codex hooks, and task model.
- Auxiliary panels inherit the pet's window level and all-Spaces behavior.

---

### Task 1: Make PetView Fixed and Event-Only

**Files:**
- Modify: `AppSources/AbigentApp/Pet/PetView.swift`

**Interfaces:**
- Produces: `onHoverChanged: (Bool) -> Void`; fixed `190 × 250 × petScale` cat content.
- Removes: inline `PetResultCard`, inline `PetControlPanel`, local card visibility/expanded/hover tasks.

- [ ] **Step 1: Replace view inputs**

Keep state, task, scale, and `onHoverChanged`. Remove control/result action inputs from `PetView`; the controller now gives those actions directly to auxiliary views.

- [ ] **Step 2: Render only cat and badge**

Use the existing `ZStack`, image, and badge, ending with:

```swift
.frame(width: 190 * petScale, height: 250 * petScale)
.contentShape(Rectangle())
.onHover(perform: onHoverChanged)
```

Make the animation helpers return resting values while a new local `isHovered` value is true, and set both `isHovered` and `onHoverChanged` from one hover callback.

- [ ] **Step 3: Build**

Run the standard Swift build command. Expected: compilation initially identifies controller call-site changes needed by Task 2; after Task 2 it succeeds.

### Task 2: Add Detached Result and Control Panels

**Files:**
- Modify: `AppSources/AbigentApp/Pet/PetWindowController.swift`
- Modify: `AppSources/AbigentApp/Pet/PetResultCard.swift`

**Interfaces:**
- Produces: `resultPanel: NSPanel`, `controlPanel: NSPanel`, `setPetHovered(_:)`, `setResultHovered(_:)`, `showResultPanel()`, `hideResultPanel()`, `toggleControlPanel()`, and `anchorAuxiliaryPanels()`.
- Consumes: existing `task`, `scale`, `alwaysOnTop`, and public action closures.

- [ ] **Step 1: Add a result-card hover wrapper**

Add a small SwiftUI wrapper that embeds `PetResultCard` and reports `.onHover` to the controller while retaining the controller-owned expanded state.

- [ ] **Step 2: Create auxiliary panels**

Create borderless, non-opaque, nonactivating `NSPanel` instances with clear backgrounds, no shadow, no background dragging, all-Spaces behavior, and the current pet level.

- [ ] **Step 3: Centralize hover timing**

Track `petHovered`, `resultHovered`, `resultExpanded`, and one cancellable `Task<Void, Never>`. Pet entry schedules show after 180 ms; both regions being false schedules hide after 250 ms unless expanded.

- [ ] **Step 4: Render auxiliary contents**

Render `PetResultCard` into the result panel when a task exists. Render the unchanged `PetControlPanel` into the control panel, wiring existing scale, pin, reset, settings, hide, quit, result, and persistence actions.

- [ ] **Step 5: Anchor without touching the pet frame**

Use the pet panel frame as read-only input. Place result left with 14 pt gap and bottom alignment, falling back right; place controls above with right alignment, falling back below. Clamp only auxiliary frames to the visible screen.

- [ ] **Step 6: Keep auxiliary lifecycle synchronized**

Re-anchor after pet drag, scale, screen changes, task changes, and panel content-size changes. Hide auxiliaries when the pet is hidden. Propagate always-on-top level changes to all panels.

- [ ] **Step 7: Remove main-panel resizing**

Delete card/control sizing state and `resizePanel(animated:)`. `setScale` changes the pet panel size while preserving its right/bottom anchor; result/control visibility never changes it.

- [ ] **Step 8: Build and commit**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk CLANG_MODULE_CACHE_PATH=/tmp/abigent-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/abigent-swiftpm-cache swift build --disable-sandbox --scratch-path /tmp/abigent-build
```

Expected: `Build complete!`.

```bash
git add AppSources/AbigentApp/Pet/PetView.swift AppSources/AbigentApp/Pet/PetWindowController.swift AppSources/AbigentApp/Pet/PetResultCard.swift
git commit -m "fix: detach pet result and control panels"
```

### Task 3: Package, Install, and Verify Build 4

**Files:**
- Generated: `dist/Abigent.app`
- Generated: `dist/Abigent-1.0.0-beta.1-macOS-arm64.dmg`

**Interfaces:**
- Consumes: `ABIGENT_VERSION=1.0.0-beta.1 ABIGENT_BUILD=4 scripts/release.sh`.
- Produces: installed build 4, refreshed DMG, and checksum.

- [ ] **Step 1: Generate the release**

```bash
ABIGENT_VERSION=1.0.0-beta.1 ABIGENT_BUILD=4 scripts/release.sh
```

Expected: production app build, helper build, signing, DMG verification, and checksum verification succeed.

- [ ] **Step 2: Install recoverably**

Quit Abigent, move build 3 to a uniquely named Trash backup, copy `dist/Abigent.app` into `/Applications`, and reopen it.

- [ ] **Step 3: Verify UI invariants**

- Hover in/out repeatedly for at least 10 seconds: result panel toggles and cat frame remains fixed.
- Move between cat and result: result remains open.
- Expand/collapse result: cat remains fixed.
- Toggle control panel and use its slider: controls work without shifting the cat.
- Explicitly drag the cat: pet moves and visible auxiliaries re-anchor.

- [ ] **Step 4: Verify artifact integrity**

Confirm version `1.0.0-beta.1`, build `4`, arm64 architecture, strict application signature, helper signature, SHA-256, and valid DMG.
