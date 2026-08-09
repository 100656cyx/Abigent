# Persistent Per-Turn Result Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep result recovery alive for delayed Codex session writes and isolate concurrent turns.

**Architecture:** Key recoveries by session and Stop time, repeat the final retry delay within a bounded ten-minute window, and preserve timestamp-based stale-result rejection.

**Tech Stack:** Swift 6.1, XCTest, Swift Package Manager, GitHub Actions.

## Global Constraints

- macOS 14+, Apple Silicon.
- Fully local processing.
- No stale previous-turn summaries.
- Publish as `v1.0.0-beta.4`.

### Task 1: Per-turn persistent recovery

**Files:**
- Modify: `AppSources/AbigentCodex/Results/CodexResultRecoveryCoordinator.swift`
- Modify: `Tests/AbigentCodexTests/CodexResultRecoveryCoordinatorTests.swift`

- [ ] Add failing tests for same-session independent Stops and retries beyond the initial schedule.
- [ ] Introduce a session-and-Stop recovery key and bounded repeated retry interval.
- [ ] Run focused and complete tests through GitHub CI.

### Task 2: beta.4 release

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `INSTALL.md`, release scripts and workflows.
- Create: `docs/releases/1.0.0-beta.4.md`.

- [ ] Update version and download guidance.
- [ ] Build and verify the arm64 DMG.
- [ ] Push source and tag, verify CI and GitHub Release assets.
- [ ] Replace and relaunch the local app.
