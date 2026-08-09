# macOS 14 Startup Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent Abigent from constructing SwiftUI hosting graphs before the root app graph exists, so the desktop pet starts successfully on Apple Silicon Macs running macOS 14.0 or newer.

**Architecture:** `PetWindowController` becomes inert at construction and gains an idempotent `start(visible:)` boundary for its first SwiftUI render. The persistent menu-bar label calls an idempotent `AppModel.applicationDidBecomeReady()` from a SwiftUI `.task`, after the root graph is attached; that method starts the pet, restores placement, connects Codex, and conditionally presents onboarding.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Package Manager, XCTest, macOS 14+

## Global Constraints

- Preserve all existing pet, menu-bar, settings, hover, drag, scale, Hook, notification, and onboarding behavior.
- Support Apple Silicon only, with deployment target macOS 14.0.
- Keep all processing local and add no dependencies or network services.
- Constructing `AppModel` and `PetWindowController` must not create an `NSHostingView` or order a window front.
- Application UI and background services must start at most once.
- Publish the correction as `v1.0.0-beta.2`; do not overwrite `v1.0.0-beta.1`.

---

### Task 1: Make Pet Window Startup Explicit and Idempotent

**Files:**
- Modify: `AppSources/AbigentApp/Pet/PetWindowController.swift`
- Modify: `Package.swift`
- Create: `Tests/AbigentAppTests/PetWindowControllerTests.swift`

**Interfaces:**
- Produces: `PetWindowController.start(visible: Bool)` and internal read-only `isStarted`.
- Consumes: existing `renderPet()`, `positionOnVisibleScreen()`, and `setVisible(_:)` behavior.

- [ ] **Step 1: Add the app target test dependency**

Add this target after `AbigentRuntimeTests` in `Package.swift`:

```swift
.testTarget(
    name: "AbigentAppTests",
    dependencies: ["AbigentApp"]
)
```

- [ ] **Step 2: Write the failing lifecycle tests**

Create `Tests/AbigentAppTests/PetWindowControllerTests.swift`:

```swift
import XCTest
@testable import AbigentApp

@MainActor
final class PetWindowControllerTests: XCTestCase {
    func testConstructionDoesNotStartSwiftUIRendering() {
        let controller = PetWindowController()
        XCTAssertFalse(controller.isStarted)
    }

    func testStartIsIdempotent() {
        let controller = PetWindowController()
        controller.start(visible: false)
        controller.start(visible: false)
        XCTAssertTrue(controller.isStarted)
    }
}
```

- [ ] **Step 3: Run the focused test and verify failure**

Run:

```bash
swift test --filter PetWindowControllerTests
```

Expected: compilation fails because `isStarted` and `start(visible:)` do not exist.

- [ ] **Step 4: Implement inert construction and explicit start**

In `PetWindowController`, add:

```swift
private(set) var isStarted = false

func start(visible: Bool) {
    guard !isStarted else {
        setVisible(visible)
        return
    }
    isStarted = true
    positionOnVisibleScreen()
    renderPet()
    setVisible(visible)
}
```

Remove `positionOnVisibleScreen()` and `renderPet()` from `init()`. Guard render-dependent mutation methods until startup:

```swift
if isStarted { renderPet() }
```

Apply that guard in `state.didSet`, `setScale`, and `apply`. Keep `setVisible(false)` safe before startup; when asked to show before startup it must return without ordering the empty panel.

- [ ] **Step 5: Run the focused test**

Run:

```bash
swift test --filter PetWindowControllerTests
```

Expected: both tests pass without an AttributeGraph fatal error.

- [ ] **Step 6: Commit the lifecycle boundary**

```bash
git add Package.swift AppSources/AbigentApp/Pet/PetWindowController.swift Tests/AbigentAppTests/PetWindowControllerTests.swift
git commit -m "fix: defer pet SwiftUI rendering until startup"
```

### Task 2: Start AppModel After the Root SwiftUI Graph Is Attached

**Files:**
- Modify: `AppSources/AbigentApp/AbigentApp.swift`
- Modify: `AppSources/AbigentApp/AppModel.swift`
- Create: `Tests/AbigentAppTests/ApplicationStartupGateTests.swift`
- Create: `AppSources/AbigentApp/ApplicationStartupGate.swift`

**Interfaces:**
- Produces: `ApplicationStartupGate.begin() -> Bool` and `AppModel.applicationDidBecomeReady() async`.
- Consumes: `PetWindowController.start(visible:)`, `PetPreferenceStore.load()`, `AppModel.start()`, and existing onboarding defaults.

- [ ] **Step 1: Write the failing startup gate test**

Create `Tests/AbigentAppTests/ApplicationStartupGateTests.swift`:

```swift
import XCTest
@testable import AbigentApp

final class ApplicationStartupGateTests: XCTestCase {
    func testBeginSucceedsOnlyOnce() {
        let gate = ApplicationStartupGate()
        XCTAssertTrue(gate.begin())
        XCTAssertFalse(gate.begin())
    }
}
```

- [ ] **Step 2: Verify the new test fails**

Run:

```bash
swift test --filter ApplicationStartupGateTests
```

Expected: compilation fails because `ApplicationStartupGate` is undefined.

- [ ] **Step 3: Add the one-shot gate**

Create `AppSources/AbigentApp/ApplicationStartupGate.swift`:

```swift
import Foundation

final class ApplicationStartupGate {
    private var started = false

    func begin() -> Bool {
        guard !started else { return false }
        started = true
        return true
    }
}
```

The gate is main-actor confined by its `AppModel` owner; it does not require locking.

- [ ] **Step 4: Remove initialization side effects from AppModel**

In `AppModel.init`, retain dependency assignment, callback wiring, Hook inspection, and `refreshOnboardingState()`. Remove:

```swift
petController.setVisible(true)
Task { ... }
DispatchQueue.main.async { ... }
```

Add `private let applicationStartupGate = ApplicationStartupGate()` and implement:

```swift
func applicationDidBecomeReady() async {
    guard applicationStartupGate.begin() else { return }
    petController.start(visible: showPet)
    let placement = await petPreferences.load()
    petScale = placement.normalizedScale
    petController.apply(placement)
    await start()
    showOnboardingAutomaticallyIfNeeded()
}
```

Move the prior UserDefaults onboarding guard into:

```swift
private func showOnboardingAutomaticallyIfNeeded() {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: Self.onboardingAutoShownKey),
          !defaults.bool(forKey: Self.onboardingCompletedKey)
    else { return }
    defaults.set(true, forKey: Self.onboardingAutoShownKey)
    showOnboarding()
}
```

- [ ] **Step 5: Trigger startup from the persistent menu-bar label**

Change `AbigentApplication` to the explicit-label `MenuBarExtra` initializer. Keep the existing content unchanged and use this label:

```swift
label: {
    Image(systemName: model.menuBarSymbol)
        .task { await model.applicationDidBecomeReady() }
}
```

This label is part of the attached root scene and does not require the user to open the menu.

- [ ] **Step 6: Run app lifecycle tests and the full suite**

Run:

```bash
swift test --filter AbigentAppTests
swift test
```

Expected: lifecycle tests and all existing tests pass. If the local Command Line Tools/SDK mismatch prevents execution, record the exact toolchain error and require the GitHub full-Xcode run plus target-machine smoke test before release.

- [ ] **Step 7: Commit root-graph startup**

```bash
git add AppSources/AbigentApp/AbigentApp.swift AppSources/AbigentApp/AppModel.swift AppSources/AbigentApp/ApplicationStartupGate.swift Tests/AbigentAppTests/ApplicationStartupGateTests.swift
git commit -m "fix: start app services after SwiftUI attaches"
```

### Task 3: Build and Verify beta.2

**Files:**
- Modify: `.github/workflows/build.yml`
- Modify: `.github/workflows/release.yml`
- Generated: `dist/Abigent.app`
- Generated: `dist/Abigent-1.0.0-beta.2-macOS-arm64.dmg`
- Generated: `dist/Abigent-1.0.0-beta.2-macOS-arm64.dmg.sha256`

**Interfaces:**
- Consumes: `Scripts/release.sh` with `ABIGENT_VERSION=1.0.0-beta.2` and `ABIGENT_BUILD=7`.
- Produces: arm64 app bundle and verified beta.2 DMG.

- [ ] **Step 1: Update CI defaults to beta.2**

Change workflow versions and expected artifact paths from `1.0.0-beta.1` to `1.0.0-beta.2`, and change the manual release default build to `7`. Preserve tag-driven prerelease creation.

- [ ] **Step 2: Build the release locally**

Run:

```bash
ABIGENT_VERSION=1.0.0-beta.2 ABIGENT_BUILD=7 Scripts/release.sh
```

Expected: the script prints paths to the beta.2 DMG and checksum and exits successfully.

- [ ] **Step 3: Verify bundle and DMG**

Run:

```bash
codesign --verify --deep --strict dist/Abigent.app
codesign --verify --strict dist/Abigent.app/Contents/Helpers/abigent-hook
test "$(lipo -archs dist/Abigent.app/Contents/MacOS/Abigent)" = "arm64"
hdiutil verify dist/Abigent-1.0.0-beta.2-macOS-arm64.dmg
cd dist && shasum -a 256 -c Abigent-1.0.0-beta.2-macOS-arm64.dmg.sha256
```

Expected: both signatures are valid, architecture is arm64, DMG verifies, and checksum reports `OK`.

- [ ] **Step 4: Smoke-test startup behavior**

Install the app in `/Applications`, clear only Abigent's quarantine attribute when necessary, and launch it. Verify first launch, repeat launch, pet display, onboarding, drag, scale, hover summary, and control panel. On the macOS 14.8.4 target, run the executable directly and verify there is no `AttributeGraph` fatal error.

- [ ] **Step 5: Commit CI version changes**

```bash
git add .github/workflows/build.yml .github/workflows/release.yml
git commit -m "ci: prepare Abigent beta.2 artifacts"
```

### Task 4: Document and Publish v1.0.0-beta.2

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `INSTALL.md`
- Modify: `docs/verification/v1-known-issues.md`
- Create: `docs/releases/1.0.0-beta.2.md`

**Interfaces:**
- Consumes: verified beta.2 DMG and checksum from Task 3.
- Produces: public beta.2 documentation, tag, source push, and GitHub prerelease assets.

- [ ] **Step 1: Add beta.2 release notes**

Create `docs/releases/1.0.0-beta.2.md` with system requirements, free-signing installation steps, and this fixed issue:

```markdown
- 修复 macOS 14 启动时可能触发 AttributeGraph fatal error、点击“打开”后无响应的问题。
```

- [ ] **Step 2: Update public documentation**

Change README download examples and local development command to beta.2. Add a `1.0.0-beta.2` changelog section and remove the macOS 14 startup crash from current known issues while retaining the free-signing Gatekeeper limitation.

- [ ] **Step 3: Validate repository hygiene**

Run:

```bash
git diff --check
git status --short
git ls-files | rg '(^dist/|tasks\.sqlite|\.codex/|\.abigent/)' && exit 1 || true
```

Expected: no whitespace errors and no generated artifacts, local databases, sockets, or Codex session data are tracked.

- [ ] **Step 4: Commit documentation**

```bash
git add README.md CHANGELOG.md INSTALL.md docs/releases/1.0.0-beta.2.md docs/verification/v1-known-issues.md
git commit -m "docs: publish Abigent beta.2 guidance"
```

- [ ] **Step 5: Push source and tag**

```bash
git push origin main
git tag -a v1.0.0-beta.2 -m "Abigent 1.0.0 Beta 2"
git push origin v1.0.0-beta.2
```

Expected: GitHub contains the updated `main` branch and annotated beta.2 tag.

- [ ] **Step 6: Publish and verify Release assets**

Create the prerelease using `docs/releases/1.0.0-beta.2.md`, upload both beta.2 files, and verify the public API reports exactly:

```text
Abigent-1.0.0-beta.2-macOS-arm64.dmg
Abigent-1.0.0-beta.2-macOS-arm64.dmg.sha256
```

Download the public DMG once, compare its SHA-256 with the uploaded checksum, and provide the repository, release, and direct-download links to the user.
