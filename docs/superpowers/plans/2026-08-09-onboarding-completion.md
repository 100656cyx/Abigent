# One-Time Onboarding Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show onboarding automatically at most once and persist successful connection after any real Hook event.

**Architecture:** `AppModel` owns two UserDefaults keys: one records that automatic onboarding has already been shown, and one records verified completion. A single verification method updates both state and UI from the Hook event stream.

**Tech Stack:** Swift 6, SwiftUI, AppKit, UserDefaults, macOS 14+

## Global Constraints

- Preferences remain local and contain no task content.
- Manual onboarding from Settings remains available.
- Do not modify Hook configuration, event normalization, task persistence, or the desktop pet.

---

### Task 1: Persist Auto-Show and Verified Completion

**Files:**
- Modify: `AppSources/AbigentApp/AppModel.swift`

**Interfaces:**
- Produces: `markOnboardingVerified()` and private key constants `onboardingAutoShown`, `onboardingCompleted`.
- Consumes: decoded events from `hookServer.events()`.

- [ ] **Step 1: Add stable preference keys**

Add private constants in `AppModel`:

```swift
private static let onboardingAutoShownKey = "onboardingAutoShown"
private static let onboardingCompletedKey = "onboardingCompleted"
```

- [ ] **Step 2: Gate automatic display once**

Replace the startup guard with logic that reads both keys. If neither is true, write `onboardingAutoShown = true` before calling `showOnboarding()`.

- [ ] **Step 3: Respect verified state during refresh**

At the start of `refreshOnboardingState()`, return `.ready` when `onboardingCompleted` is true; otherwise continue Codex and Hook inspection.

- [ ] **Step 4: Centralize completion**

Implement:

```swift
func markOnboardingVerified() {
    UserDefaults.standard.set(true, forKey: Self.onboardingAutoShownKey)
    UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
    onboardingState = .ready
    dismissOnboarding()
}
```

Make `completeOnboarding()` call this method.

- [ ] **Step 5: Verify on every decoded Hook envelope**

In the Hook event loop, call `markOnboardingVerified()` on the main actor before normalizing every received envelope. Remove the SessionStart-only ready condition.

- [ ] **Step 6: Build and commit**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk CLANG_MODULE_CACHE_PATH=/tmp/abigent-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/abigent-swiftpm-cache swift build --disable-sandbox --scratch-path /tmp/abigent-build
```

Expected: `Build complete!`.

```bash
git add AppSources/AbigentApp/AppModel.swift
git commit -m "fix: remember onboarding completion"
```

### Task 2: Package and Restart-Verify Build 5

**Files:**
- Generated: `dist/Abigent.app`
- Generated: `dist/Abigent-1.0.0-beta.1-macOS-arm64.dmg`

**Interfaces:**
- Consumes: `ABIGENT_VERSION=1.0.0-beta.1 ABIGENT_BUILD=5 scripts/release.sh`.
- Produces: installed build 5, versioned DMG, and checksum.

- [ ] **Step 1: Generate release artifacts**

```bash
ABIGENT_VERSION=1.0.0-beta.1 ABIGENT_BUILD=5 scripts/release.sh
```

- [ ] **Step 2: Install recoverably**

Quit Abigent, move build 4 to a uniquely named Trash backup, copy the new app into Applications, and reopen it.

- [ ] **Step 3: Verify one-time auto display**

On the existing profile, allow the first build-5 launch to record `onboardingAutoShown`. Close onboarding, quit Abigent, and reopen it. Expected: the onboarding window does not appear automatically and the cat remains available.

- [ ] **Step 4: Verify artifact integrity**

Confirm version `1.0.0-beta.1`, build `5`, arm64, strict application and helper signatures, SHA-256, valid DMG, and private Hook socket permissions.
