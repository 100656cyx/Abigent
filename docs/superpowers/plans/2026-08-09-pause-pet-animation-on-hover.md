# Pause Pet Animation on Hover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pause the cat artwork while hovered, remove the persistent resize handle, and ensure the desktop position changes only after an explicit primary-button drag on the cat.

**Architecture:** Keep hover behavior local to `PetView` with one `@State` flag shared by animation rendering and result-card visibility. Remove the handle from the view hierarchy while preserving the control-panel slider callbacks into `PetWindowController`.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Package Manager, macOS 14+

## Global Constraints

- The progress spinner and status badges continue to animate while the cat artwork is paused.
- The result card retains its existing 180 ms show and 250 ms hide delays.
- Pet scaling remains available from the secondary-click control panel at 50%–150% and remains persisted.
- Do not modify task state, Codex connectivity, or persistence formats.
- Hover, pointer movement, scrolling, result-card visibility, and control-panel interaction must not drag the pet window.

---

### Task 1: Pause Cat Artwork Across the Hover Region

**Files:**
- Modify: `AppSources/AbigentApp/Pet/PetView.swift`

**Interfaces:**
- Consumes: existing `scheduleVisibility(_ hovering: Bool)` hover callback.
- Produces: `@State private var pointerInsideInteractionArea: Bool`; animation helpers return resting values while true.

- [ ] **Step 1: Add hover state and make animation helpers hover-aware**

Add the state:

```swift
@State private var pointerInsideInteractionArea = false
```

At the start of `scheduleVisibility`, assign the current hover value:

```swift
pointerInsideInteractionArea = hovering
```

Update the three artwork helpers so hover has the same resting behavior as Reduce Motion:

```swift
guard !reduceMotion, !pointerInsideInteractionArea else { return 1 }
```

```swift
guard !reduceMotion, !pointerInsideInteractionArea else { return .zero }
```

```swift
guard !reduceMotion, !pointerInsideInteractionArea, state == .completed else { return 0 }
```

- [ ] **Step 2: Use one hover boundary for the complete interaction area**

Move the visibility callback to the outer `HStack` so moving between the cat and result card does not generate a false exit/enter cycle:

```swift
HStack(alignment: .bottom, spacing: 14) {
    // existing result card and cat content
}
.onHover(perform: scheduleVisibility)
```

Remove the two inner `.onHover(perform: scheduleVisibility)` modifiers.

- [ ] **Step 3: Build the production targets**

Run:

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk CLANG_MODULE_CACHE_PATH=/tmp/abigent-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/abigent-swiftpm-cache swift build --disable-sandbox --scratch-path /tmp/abigent-build
```

Expected: build completes successfully.

### Task 2: Remove the Persistent Resize Handle

**Files:**
- Modify: `AppSources/AbigentApp/Pet/PetView.swift`

**Interfaces:**
- Consumes: existing `PetControlPanel` callbacks `onScaleChanged` and `onScaleEnded`.
- Produces: no new interface; removes only the `PetResizeHandle` view instance.

- [ ] **Step 1: Remove the handle from the cat ZStack**

Delete this block:

```swift
PetResizeHandle(
    scale: petScale,
    onScaleChanged: onScaleChanged,
    onScaleEnded: onScaleEnded
)
.padding(4)
```

Keep both callbacks on `PetControlPanel` unchanged.

- [ ] **Step 2: Verify the source no longer instantiates the handle**

Run:

```bash
rg -n "PetResizeHandle" AppSources/AbigentApp/Pet/PetView.swift
```

Expected: no matches.

- [ ] **Step 3: Commit the source change**

```bash
git add AppSources/AbigentApp/Pet/PetView.swift
git commit -m "fix: steady the pet while hovering"
```

### Task 3: Require an Explicit Cat Drag

**Files:**
- Modify: `AppSources/AbigentApp/Pet/PetWindowController.swift`

**Interfaces:**
- Consumes: `PetWindowController.basePetSize` and the current pet scale.
- Produces: `SecondaryClickHostingView.petDragAreaSize: CGSize`; primary mouse-down inside the bottom-right cat rectangle calls `NSWindow.performDrag(with:)`.

- [ ] **Step 1: Add a bounded explicit drag area**

Extend `SecondaryClickHostingView`:

```swift
var petDragAreaSize = CGSize.zero

override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let dragArea = CGRect(
        x: bounds.maxX - petDragAreaSize.width,
        y: bounds.minY,
        width: petDragAreaSize.width,
        height: petDragAreaSize.height
    )
    guard dragArea.contains(point) else {
        super.mouseDown(with: event)
        return
    }
    window?.performDrag(with: event)
}
```

- [ ] **Step 2: Disable implicit background dragging**

In `PetWindowController.init`, replace:

```swift
panel.isMovableByWindowBackground = true
```

with:

```swift
panel.isMovableByWindowBackground = false
```

After creating the hosting view in `render()`, set:

```swift
hosting.petDragAreaSize = CGSize(
    width: Self.basePetSize.width * scale,
    height: Self.basePetSize.height * scale
)
```

- [ ] **Step 3: Prevent hover-card frame interpolation**

Change `setCardVisible` to resize without animation:

```swift
private func setCardVisible(_ visible: Bool) {
    cardVisible = visible
    resizePanel(animated: false)
}
```

- [ ] **Step 4: Build and commit**

Run the production build command from Task 1. Expected: build succeeds.

```bash
git add AppSources/AbigentApp/Pet/PetWindowController.swift
git commit -m "fix: move the pet only on explicit drag"
```

### Task 4: Package, Install, and Verify

**Files:**
- Modify generated artifact: `dist/Abigent.app`
- Modify generated artifact: `dist/Abigent-1.0.0-beta.1-macOS-arm64.dmg`

**Interfaces:**
- Consumes: `ABIGENT_VERSION=1.0.0-beta.1 ABIGENT_BUILD=3 scripts/release.sh`.
- Produces: installed build 3 and refreshed versioned DMG/checksum.

- [ ] **Step 1: Build release artifacts**

Run:

```bash
ABIGENT_VERSION=1.0.0-beta.1 ABIGENT_BUILD=3 scripts/release.sh
```

Expected: app and DMG are built, signed, and verified.

- [ ] **Step 2: Install the updated app recoverably**

Quit Abigent, move the previous `/Applications/Abigent.app` to a uniquely named item in Trash, copy `dist/Abigent.app` into Applications, and reopen it.

- [ ] **Step 3: Verify the interaction in the installed app**

Check with the macOS UI:

- Hovering the cat for at least 10 seconds opens the result card, keeps the artwork still, and does not change the cat's desktop anchor.
- The working progress spinner remains active.
- The bottom-right resize handle is absent.
- Secondary click opens the control panel.
- The control-panel slider remains present and reports the current percentage.
- Pressing and dragging the cat moves the window; moving the pointer without pressing does not.

- [ ] **Step 4: Verify package integrity**

Run checksum, `hdiutil verify`, `codesign --verify --deep --strict`, and confirm the installed bundle reports version `1.0.0-beta.1`, build `3`, and arm64 architecture.
