# Free GitHub Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a transferable ad-hoc-signed DMG with built-in opening instructions and prepare a clean GitHub repository and release workflow.

**Architecture:** A single tracked distribution guide is copied into every DMG. Local and GitHub Actions workflows use the existing build pipeline, verify the app and DMG, and expose artifacts without storing signing credentials or bypassing Gatekeeper.

**Tech Stack:** Bash, Swift 6, macOS DMG tools, GitHub Actions, Markdown

## Global Constraints

- Free personal distribution only; no Developer ID or notarization claims.
- Do not disable Gatekeeper or remove quarantine attributes.
- Do not commit credentials, local databases, sockets, sessions, build output, or `AGENTS.md`.
- Target Apple Silicon and macOS 14+.

---

### Task 1: Add the Recipient Installation Guide to DMG

**Files:**
- Create: `Resources/Distribution/首次打开说明.txt`
- Modify: `Scripts/create-dmg.sh`

**Interfaces:**
- `Scripts/create-dmg.sh <app> <dmg>` copies the tracked guide into its temporary staging directory.

- [ ] **Step 1: Write the guide**

Include system requirements, drag-to-Applications, first launch, Privacy & Security → Open Anyway, Hook enablement, full Codex restart, verification, upgrade, and uninstall instructions. Explicitly state that the Beta is ad-hoc signed and not notarized.

- [ ] **Step 2: Copy the guide into staging**

Add:

```bash
guide_path="$project_root/Resources/Distribution/首次打开说明.txt"
test -f "$guide_path"
cp "$guide_path" "$stage/首次打开说明.txt"
```

- [ ] **Step 3: Commit**

```bash
git add Resources/Distribution/首次打开说明.txt Scripts/create-dmg.sh
git commit -m "release: include free install guide"
```

### Task 2: Refresh Public Repository Documentation

**Files:**
- Modify: `README.md`
- Create: `INSTALL.md`
- Modify: `CHANGELOG.md`
- Create: `docs/releases/1.0.0-beta.1.md`
- Modify: `.gitignore`

- [ ] **Step 1: Update README**

Describe the fixed cat window, detached result/control panels, right-click-only scaling, current install flow, privacy model, correct script casing, and unsigned Beta limitation.

- [ ] **Step 2: Add INSTALL and release notes**

Make INSTALL operational for non-developers. Make release notes ready to paste into a GitHub Release and list the exact DMG and checksum names.

- [ ] **Step 3: Update changelog and ignore rules**

Record build 2–5 fixes and add `/AGENTS.md` to `.gitignore`.

- [ ] **Step 4: Check public copy consistency and commit**

Search for the removed resize handle, wrong script casing, notarization claims, and mismatched artifact names. Then commit all public docs.

### Task 3: Prepare GitHub CI and Manual Release Artifacts

**Files:**
- Modify: `.github/workflows/build.yml`
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Strengthen CI verification**

After building, create the DMG and verify app signature, Helper signature, arm64 architecture, DMG integrity, and presence of the installation guide. Upload the DMG and checksum rather than a bare `.app`.

- [ ] **Step 2: Add manual release workflow**

Use `workflow_dispatch` inputs `version` and `build`; run tests, call:

```bash
ABIGENT_VERSION="$VERSION" ABIGENT_BUILD="$BUILD" scripts/release.sh
```

Upload the matching DMG and `.sha256` as an Actions artifact. Do not create a public GitHub Release automatically.

- [ ] **Step 3: Parse and inspect workflow YAML**

Use Ruby's standard YAML parser with aliases enabled, then inspect all referenced paths for exact case.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/build.yml .github/workflows/release.yml
git commit -m "ci: package free macOS release artifacts"
```

### Task 4: Build and Audit Share Build 6

**Files:**
- Generated: `dist/Abigent.app`
- Generated: `dist/Abigent-1.0.0-beta.1-macOS-arm64.dmg`
- Generated: `dist/Abigent-1.0.0-beta.1-macOS-arm64.dmg.sha256`

- [ ] **Step 1: Build**

```bash
ABIGENT_VERSION=1.0.0-beta.1 ABIGENT_BUILD=6 scripts/release.sh
```

- [ ] **Step 2: Inspect mounted contents**

Attach the DMG read-only and confirm it contains `Abigent.app`, `Applications`, and `首次打开说明.txt`; detach it afterward.

- [ ] **Step 3: Verify security and integrity**

Run strict app and Helper signature verification, check Hardened Runtime, arm64, SHA-256, DMG verification, and Gatekeeper assessment. Gatekeeper may report rejection because the free build is not notarized; document that expected limitation.

- [ ] **Step 4: Audit repository contents**

Confirm Git status excludes `AGENTS.md`, `dist/`, `.codex`, local task databases, sockets, sessions, certificates, keys, and common credential patterns.
