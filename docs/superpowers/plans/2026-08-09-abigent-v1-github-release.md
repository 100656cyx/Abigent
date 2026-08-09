# Abigent V1 GitHub Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an Apple Silicon macOS 14+ Abigent Beta that installs from a GitHub DMG, follows Codex tasks reliably, shows the current turn result, and provides a resizable desktop cat with a two-finger control panel.

**Architecture:** Keep the existing local Hook → Unix Socket → normalized event → task coordinator pipeline. Add a pure geometry/settings layer for pet sizing, a SwiftUI control panel driven by AppModel, an onboarding state machine that verifies a post-install Codex restart, and deterministic release scripts that emit a versioned DMG plus SHA-256.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, SQLite, Swift Package Manager, XCTest, shell release scripts, GitHub Releases.

## Global Constraints

- Support Apple Silicon arm64 only and macOS 14.0 or newer.
- Support Codex desktop only in V1.
- Keep prompts, replies, file lists, tests, settings, and diagnostics local.
- Do not add analytics, cloud services, accounts, automatic updates, Trae CN, Intel support, or Apple notarization.
- Preserve all non-Abigent Hook commands, matchers, ordering, and unknown JSON fields.
- Keep `sources/` read-only and use `AppSources/` for application code.
- Do not declare release-ready until the full XCTest suite passes with complete Xcode.

---

### Task 1: Pet Size and Position Model

**Files:**
- Create: `AppSources/AbigentCore/PetPlacement.swift`
- Create: `AppSources/AbigentPersistence/PetPreferenceStore.swift`
- Modify: `Package.swift`
- Test: `Tests/AbigentCoreTests/PetPlacementTests.swift`
- Test: `Tests/AbigentPersistenceTests/PetPreferenceStoreTests.swift`

**Interfaces:**
- Produces: `PetPlacement(scale:origin:)`, `PetPlacement.clamped(to:petSize:)`, and actor `PetPreferenceStore.load()/save(_:)`.
- Consumes: normalized scale `0.5...1.5`, AppKit-independent rectangles represented by `CGRect`.

- [ ] **Step 1: Write failing geometry tests**

Cover clamping scale below 0.5 and above 1.5, preserving an in-bounds origin, pulling every edge back into a visible screen, and restoring a 1.0 default.

```swift
func testPlacementClampsScaleAndOriginToVisibleFrame() {
    let placement = PetPlacement(scale: 2, origin: CGPoint(x: 990, y: -20))
    let clamped = placement.clamped(
        to: CGRect(x: 0, y: 0, width: 1000, height: 800),
        petSize: CGSize(width: 190, height: 250)
    )
    XCTAssertEqual(clamped.scale, 1.5)
    XCTAssertGreaterThanOrEqual(clamped.origin.y, 0)
    XCTAssertLessThanOrEqual(clamped.origin.x + 190 * 1.5, 1000)
}
```

- [ ] **Step 2: Implement `PetPlacement`**

Use a Codable, Sendable, Equatable value with `minimumScale = 0.5`, `maximumScale = 1.5`, `defaultScale = 1.0`; clamp scaled width/height and origin independently to the visible frame.

- [ ] **Step 3: Write failing persistence tests**

Use a temporary UserDefaults suite. Assert missing data returns the default, saved placement round-trips, and corrupt data resets safely.

- [ ] **Step 4: Implement `PetPreferenceStore`**

Encode one `PetPlacement` JSON blob under `com.abigent.desktop.pet-placement`; never write project or conversation data to UserDefaults.

- [ ] **Step 5: Run tests and commit**

Run `swift test --filter 'PetPlacementTests|PetPreferenceStoreTests'`. Expected with complete Xcode: PASS. On the current Command Line Tools environment, record the known `no such module 'XCTest'` blocker after production compilation succeeds.

```bash
git add Package.swift AppSources/AbigentCore/PetPlacement.swift AppSources/AbigentPersistence/PetPreferenceStore.swift Tests/AbigentCoreTests/PetPlacementTests.swift Tests/AbigentPersistenceTests/PetPreferenceStoreTests.swift
git commit -m "feat: persist desktop pet placement"
```

### Task 2: Resizable Pet Window and Handle

**Files:**
- Modify: `AppSources/AbigentApp/Pet/PetWindowController.swift`
- Modify: `AppSources/AbigentApp/Pet/PetView.swift`
- Create: `AppSources/AbigentApp/Pet/PetResizeHandle.swift`
- Modify: `AppSources/AbigentApp/AppModel.swift`

**Interfaces:**
- Consumes: `PetPlacement`, `PetPreferenceStore`, base pet size `190×250`.
- Produces: `PetWindowController.setScale(_:)`, `resetScale()`, `placementDidChange`, and a bottom-right drag handle.

- [ ] **Step 1: Add placement state to AppModel**

Expose read-only `petScale`, `petScalePercent`, `setPetScale(_:)`, and `resetPetScale()`. Load preferences before the first visible placement and save changes after drag end.

- [ ] **Step 2: Implement scaled window geometry**

Keep the panel right/bottom anchor stable while resizing. Scale only the cat surface; keep the result card at a fixed 350-point content width and include it in the expanded panel width calculation.

- [ ] **Step 3: Implement the resize handle**

Render a 27-point circular handle at the cat's bottom-right. Convert horizontal-plus-vertical drag distance into a uniform scale, clamp to 0.5...1.5, and save on gesture end. Dragging the cat body continues moving the panel.

- [ ] **Step 4: Handle screen changes**

Observe `NSApplication.didChangeScreenParametersNotification`, choose the panel's current screen or nearest screen, clamp placement, and persist the corrected origin.

- [ ] **Step 5: Build, visually inspect, and commit**

Run the production build, then inspect 50%, 100%, and 150% on desktop. Expected: no cropping, handle remains reachable, and result card text size does not change.

```bash
git add AppSources/AbigentApp/AppModel.swift AppSources/AbigentApp/Pet
git commit -m "feat: resize the desktop pet"
```

### Task 3: Two-Finger Branded Control Panel

**Files:**
- Create: `AppSources/AbigentApp/Pet/PetControlPanel.swift`
- Create: `AppSources/AbigentApp/Pet/PetSecondaryClickView.swift`
- Modify: `AppSources/AbigentApp/Pet/PetView.swift`
- Modify: `AppSources/AbigentApp/Pet/PetWindowController.swift`
- Modify: `AppSources/AbigentApp/AppModel.swift`

**Interfaces:**
- Consumes: AppModel actions for scale, visibility, always-on-top, settings, result, and quit.
- Produces: a custom popover triggered by macOS secondary click from trackpad or mouse.

- [ ] **Step 1: Bridge the AppKit secondary-click event**

Create an `NSViewRepresentable` whose backing `NSView.rightMouseDown(with:)` invokes `onSecondaryClick` with panel-local coordinates. This supports two-finger trackpad clicks and mouse right-click without Accessibility permission.

- [ ] **Step 2: Implement `PetControlPanel`**

Build the approved translucent panel with six actions: result, pin, reset size, settings, hide, quit. Add a 50%–150% slider and current percentage label. Use destructive styling only for quit.

- [ ] **Step 3: Add close behavior and positioning**

Open above-left of the cat, remain inside the visible screen, and close on outside click, Escape, action completion, or a second secondary click.

- [ ] **Step 4: Connect every action**

“结果” pins the current hover card; “置顶” toggles panel level; “设置” opens the settings scene; “隐藏” keeps the menu-bar entry available; “退出” terminates cleanly after stopping the local Socket.

- [ ] **Step 5: Build, exercise trackpad and mouse, and commit**

Expected: two-finger click and right-click open the same panel; body drag and resize drag do not accidentally open it.

```bash
git add AppSources/AbigentApp/AppModel.swift AppSources/AbigentApp/Pet
git commit -m "feat: add desktop pet control panel"
```

### Task 4: First-Run Hook Onboarding and Restart Verification

**Files:**
- Create: `AppSources/AbigentApp/Onboarding/OnboardingState.swift`
- Create: `AppSources/AbigentApp/Onboarding/OnboardingView.swift`
- Modify: `AppSources/AbigentApp/AbigentApp.swift`
- Modify: `AppSources/AbigentApp/AppModel.swift`
- Modify: `AppSources/AbigentApp/Settings/HookSetupView.swift`
- Modify: `AppSources/AbigentCodex/Hooks/CodexHookInstaller.swift`
- Test: `Tests/AbigentCodexTests/CodexHookInstallerTests.swift`

**Interfaces:**
- Produces: onboarding states `detecting`, `codexMissing`, `hookNotInstalled`, `restartRequired(installedAt:)`, `waitingForSessionStart`, `ready`, and `failed(message:)`.
- Consumes: Hook install status, receipt installation date, app process start time when available, and the first real Hook SessionStart observed after installation.

- [ ] **Step 1: Write Hook migration tests**

Assert install and repair put exactly one Abigent entry in the first existing group, preserve all third-party JSON after owned-entry removal, and migrate the old standalone-last-group layout.

- [ ] **Step 2: Implement onboarding state transitions**

Never claim ready from file inspection alone. After install/repair, show restart required; after Codex relaunch, wait for a real SessionStart on the Abigent Socket; only then persist onboarding completion.

- [ ] **Step 3: Build the first-run view**

Use non-technical Chinese copy, one primary action per state, and a final guided test: “在 Codex 发送任务 → 看小猫工作 → 完成后悬停查看摘要”. Provide a diagnostics disclosure without exposing Hook command strings.

- [ ] **Step 4: Integrate settings and migration**

Existing users with the old unreachable Hook grouping see “修复配置”; after repair they see the restart requirement. Disabling removes only owned entries.

- [ ] **Step 5: Verify and commit**

Use fixtures for no config, Flux-only config, multiple groups, old Abigent standalone groups, malformed JSON, and uninstall. Expected: non-Abigent semantic hash is identical before and after.

```bash
git add AppSources/AbigentApp/Onboarding AppSources/AbigentApp/AppModel.swift AppSources/AbigentApp/AbigentApp.swift AppSources/AbigentApp/Settings/HookSetupView.swift AppSources/AbigentCodex/Hooks/CodexHookInstaller.swift Tests/AbigentCodexTests/CodexHookInstallerTests.swift
git commit -m "feat: guide first-run Codex connection"
```

### Task 5: Public Repository Documentation and Deterministic Release

**Files:**
- Modify: `README.md`
- Create: `PRIVACY.md`
- Create: `LICENSE`
- Create: `CHANGELOG.md`
- Create: `CONTRIBUTING.md`
- Create: `Scripts/release.sh`
- Modify: `Scripts/build-app.sh`
- Modify: `Scripts/create-dmg.sh`
- Modify: `Resources/Info.plist`
- Create: `.github/workflows/build.yml`

**Interfaces:**
- Produces: `dist/Abigent-v1.0.0-beta.1-macOS-arm64.dmg` and matching `.sha256`.
- Consumes: clean git revision, semantic version, macOS 15.4+ SDK, arm64 Swift release build.

- [ ] **Step 1: Write public documentation**

README must cover installation, the unsigned-app Privacy & Security step, Hook setup, required Codex restart, pet controls, uninstall, troubleshooting, local data paths, Apple Silicon limitation, and actual checked-in screenshots or GIF assets. PRIVACY must state no analytics or network upload. Use the standard MIT text with year 2026 and copyright holder `Abigent contributors`.

- [ ] **Step 2: Make build metadata configurable**

Read `ABIGENT_VERSION` and `ABIGENT_BUILD` in `release.sh`, copy Info.plist to a staging location, update the staged bundle with PlistBuddy, and never rewrite tracked version files during release.

- [ ] **Step 3: Produce versioned artifacts**

Build arm64 App and Helper, ad-hoc sign nested code then outer app, verify with `codesign --verify --deep --strict`, create and verify the DMG, and run `shasum -a 256` into a sibling `.sha256` file.

- [ ] **Step 4: Add CI build verification**

On macOS runners, run production build and XCTest, then upload unsigned CI artifacts only for inspection. GitHub Release publication remains a deliberate local command until signing/notarization is added.

- [ ] **Step 5: Run shell checks and commit**

Run `bash -n Scripts/*.sh`, release the beta artifact, verify checksum with `shasum -a 256 -c`, mount/unmount the DMG, and confirm bundle architecture is arm64.

```bash
git add README.md PRIVACY.md LICENSE CHANGELOG.md CONTRIBUTING.md Scripts Resources/Info.plist .github/workflows/build.yml
git commit -m "release: prepare Abigent V1 beta"
```

### Task 6: Full Product Verification and Release Decision

**Files:**
- Create: `docs/verification/v1-test-matrix.md`
- Modify: `docs/verification/release-checklist.md`
- Create: `docs/verification/v1-known-issues.md`

**Interfaces:**
- Consumes: beta DMG, full XCTest output, clean Apple Silicon test Mac, Codex desktop, optional Flux Island installation.
- Produces: a pass/fail release record with evidence for every blocker in the V1 specification.

- [ ] **Step 1: Run the complete automated suite**

Install/select full Xcode, run `swift test`, and save test counts and failures in the matrix. Any failure blocks release; Command Line Tools-only results do not qualify.

- [ ] **Step 2: Run clean-install and upgrade scenarios**

Test a clean user account or clean Apple Silicon Mac, then upgrade from 0.2.1. Confirm data preservation, first-open instructions, Hook onboarding, Codex restart detection, and uninstall.

- [ ] **Step 3: Run task-state scenarios**

Record timestamps and outcomes for new session, resumed session, three consecutive turns, two parallel sessions, approval request, failure, cancellation, Abigent restart mid-task, and Socket recovery. Every completed turn must show its own exact summary.

- [ ] **Step 4: Run Hook coexistence scenarios**

Test no third-party Hooks, Flux Island, and a synthetic second third-party command. Compare normalized non-Abigent JSON before install, repair, and uninstall; hashes must match.

- [ ] **Step 5: Run pet visual scenarios**

Verify 50%, 100%, 150%, continuous resize, secondary click, mouse right-click, position persistence, multiple displays, display removal, desktop Spaces, result card edges, hide/show, and quit.

- [ ] **Step 6: Decide release readiness and commit evidence**

If every blocker passes, mark `1.0.0-beta.1` ready and attach artifact names/checksums. Otherwise list each reproducible issue with severity and keep the release blocked.

```bash
git add docs/verification/v1-test-matrix.md docs/verification/release-checklist.md docs/verification/v1-known-issues.md
git commit -m "test: verify Abigent V1 beta"
```
