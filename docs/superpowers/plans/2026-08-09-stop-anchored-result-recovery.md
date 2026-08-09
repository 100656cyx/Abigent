# Stop-Anchored Result Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Codex result extraction bound to the turn that emitted Stop, even when another turn starts during retry.

**Architecture:** Parse JSONL timestamps into turn boundaries and select the turn at `stopObservedAt`. Preserve latest-turn fallback for records without timestamps, then release the tested correction as beta.3.

**Tech Stack:** Swift 6.1, XCTest, Swift Package Manager, macOS DMG tooling, GitHub Releases.

## Global Constraints

- Support macOS 14 or later on arm64.
- Keep all processing local.
- Preserve legacy timestamp-free JSONL behavior.
- Publish as `v1.0.0-beta.3`; do not overwrite beta.2.

---

### Task 1: Anchor result extraction to Stop time

**Files:**
- Modify: `Tests/AbigentCodexTests/CodexResultExtractorTests.swift`
- Modify: `AppSources/AbigentCodex/Results/CodexResultExtractor.swift`

**Interfaces:**
- Consumes: `extract(sessionID:stopObservedAt:)` and JSONL root `timestamp`.
- Produces: the `TaskResult` for the turn active at the Stop timestamp.

- [ ] Add a failing regression test where a new turn begins after Stop.
- [ ] Run the focused test and verify the old parser returns pending instead of the preceding result.
- [ ] Parse timestamps and constrain message/file selection to the anchored turn range.
- [ ] Run extractor tests and the complete Swift test suite.
- [ ] Commit the tested bug fix.

### Task 2: Prepare beta.3 release metadata

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `Scripts/release.sh`
- Modify: `.github/workflows/build.yml`
- Modify: `.github/workflows/release.yml`
- Create: `docs/releases/1.0.0-beta.3.md`

**Interfaces:**
- Consumes: the tested Stop-anchored extractor.
- Produces: beta.3 source guidance and release automation defaults.

- [ ] Change current download and build defaults from beta.2 to beta.3.
- [ ] Document the same-session rapid-follow-up fix and free-signing installation requirement.
- [ ] Verify documentation links and workflow artifact names.
- [ ] Commit release metadata.

### Task 3: Build, install, and publish beta.3

**Files:**
- Generated: `dist/Abigent-1.0.0-beta.3-macOS-arm64.dmg`
- Generated: `dist/Abigent-1.0.0-beta.3-macOS-arm64.dmg.sha256`

**Interfaces:**
- Consumes: `ABIGENT_VERSION=1.0.0-beta.3 ABIGENT_BUILD=8 Scripts/release.sh`.
- Produces: a verified local app and public GitHub prerelease.

- [ ] Build the beta.3 app and DMG.
- [ ] Verify checksum, signature structure, architecture, version, and test suite.
- [ ] Replace the local `/Applications/Abigent.app` and relaunch it.
- [ ] Push commits and annotated `v1.0.0-beta.3` tag.
- [ ] Create the GitHub prerelease and upload the DMG and checksum.
- [ ] Verify the public release and direct-download URLs.
