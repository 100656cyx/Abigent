# Codex Hook Trust Troubleshooting Documentation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Document how to identify and resolve the state where Abigent Hooks are present but not individually trusted by Codex.

**Architecture:** Add a short README fix, expand installation verification into three explicit states, publish a standalone sanitized case study, and tighten the live Hook acceptance criteria. All four documents use the same seven event names and never recommend bypassing Codex trust.

**Tech Stack:** Markdown, Codex `hooks.json`, Codex `hooks.state`, local Unix Socket, SQLite diagnostics

## Global Constraints

- Do not include real session IDs, prompts, replies, usernames, or personal absolute paths.
- Do not advise editing `trusted_hash`, bypassing Hook trust, or disabling Codex security.
- Preserve Flux Island and all non-Abigent Hook configuration.
- Treat manual Relay injection as transport diagnosis, not proof that Codex executes the Hook.

---

### Task 1: Publish the User-Facing Trust Fix

**Files:**
- Modify: `README.md`
- Modify: `INSTALL.md`
- Create: `docs/troubleshooting/codex-hook-trust.md`

**Interfaces:**
- Consumes: current seven Abigent events and Codex per-handler trust behavior.
- Produces: quick recovery instructions and a complete sanitized diagnostic case.

- [ ] **Step 1: Add the README quick fix**

Add a troubleshooting item explaining that a complete `hooks.json` or working Flux Island Hook does not prove Abigent is trusted. Direct users to trust commands containing `Abigent.app/Contents/Helpers/abigent-hook`, restart Codex with `⌘Q`, and send a new task.

- [ ] **Step 2: Expand the installation verification states**

In `INSTALL.md`, document these exact stages:

```text
配置已写入
等待 Codex 信任
已收到真实事件
```

List `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `Stop`, and `SubagentStop`. State that Flux Island trust does not extend to Abigent in the same matcher group.

- [ ] **Step 3: Write the standalone case study**

Create `docs/troubleshooting/codex-hook-trust.md` with symptoms, misleading green signals, layered diagnosis, positional handler trust root cause, safe user recovery, maintainer acceptance criteria, and the future three-state onboarding lesson.

- [ ] **Step 4: Verify public wording and privacy**

```bash
rg -n 'SessionStart|UserPromptSubmit|PreToolUse|PermissionRequest|PostToolUse|Stop|SubagentStop' INSTALL.md docs/troubleshooting/codex-hook-trust.md
rg -n '019fe|/Users/|真实 Prompt|trusted_hash.*=' README.md INSTALL.md docs/troubleshooting/codex-hook-trust.md && exit 1 || true
git diff --check
```

Expected: all seven events appear, while no real identifier, personal path, prompt content, or trusted-hash editing instruction appears.

### Task 2: Tighten Hook Acceptance and Publish

**Files:**
- Modify: `docs/verification/hook-live-check.md`
- Modify: `README.md`
- Modify: `INSTALL.md`
- Create: `docs/troubleshooting/codex-hook-trust.md`

**Interfaces:**
- Consumes: Task 1 user documentation.
- Produces: a release-grade verification rule, committed source, and updated GitHub documentation.

- [ ] **Step 1: Separate intermediate checks from live acceptance**

Update `hook-live-check.md` so configuration merge, private Socket creation, and manual Relay injection are explicitly intermediate diagnostics. Require a new real Codex task to create a Hook-provenance database update, drive the pet within one second, and recover the matching Stop result.

- [ ] **Step 2: Add the troubleshooting guide to README project documents**

Add a `Codex Hook 信任排障` link pointing to `docs/troubleshooting/codex-hook-trust.md`.

- [ ] **Step 3: Validate repository hygiene**

```bash
git diff --check
git status --short
git ls-files | rg 'tasks\.sqlite|\.abigent/|\.codex/sessions' && exit 1 || true
```

Expected: only documentation changes, no runtime data or session files.

- [ ] **Step 4: Commit and push**

```bash
git add README.md INSTALL.md docs/troubleshooting/codex-hook-trust.md docs/verification/hook-live-check.md
git commit -m "docs: explain Codex Hook trust troubleshooting"
git push origin main
```

- [ ] **Step 5: Verify GitHub public content**

Confirm the public README links to the case study and the raw GitHub versions of README, INSTALL, the case study, and Hook live check contain the new trust guidance.
