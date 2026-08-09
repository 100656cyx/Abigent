# GitHub Homepage Beta 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the user-provided Abigent usage screenshot on the GitHub homepage and direct all new users to `v1.0.0-beta.2`.

**Architecture:** Store the unchanged PNG under `docs/assets` and reference it with a repository-relative Markdown image. Add a compact current-version callout and stable GitHub Release links before the screenshot, leaving historical Beta 1 documentation intact.

**Tech Stack:** Markdown, PNG, Git, GitHub Releases

## Global Constraints

- Do not crop, redraw, compress, or watermark the screenshot.
- Recommend exactly `v1.0.0-beta.2` and warn that Beta 1 has a macOS 14 startup issue.
- Keep Beta 1 history and release notes available.
- Do not modify application code, packages, or Release assets.

---

### Task 1: Add the Product Screenshot

**Files:**
- Source: `/var/folders/7k/6z04fgh50hl7_qcb8hhcff800000gn/T/codex-clipboard-c87b8101-a6f0-4929-89b2-5627155aded2.png`
- Create: `docs/assets/abigent-beta2-overview.png`

**Interfaces:**
- Consumes: the user-provided 1174×476 RGBA PNG.
- Produces: the stable relative asset path used by `README.md`.

- [ ] **Step 1: Create the asset directory and copy the original bytes**

```bash
mkdir -p docs/assets
cp /var/folders/7k/6z04fgh50hl7_qcb8hhcff800000gn/T/codex-clipboard-c87b8101-a6f0-4929-89b2-5627155aded2.png docs/assets/abigent-beta2-overview.png
```

- [ ] **Step 2: Verify exact byte preservation and dimensions**

```bash
cmp /var/folders/7k/6z04fgh50hl7_qcb8hhcff800000gn/T/codex-clipboard-c87b8101-a6f0-4929-89b2-5627155aded2.png docs/assets/abigent-beta2-overview.png
sips -g pixelWidth -g pixelHeight docs/assets/abigent-beta2-overview.png
```

Expected: `cmp` exits successfully; dimensions are `1174` × `476`.

### Task 2: Update and Verify the GitHub Homepage

**Files:**
- Modify: `README.md`
- Test: GitHub public `main` branch README and Release URLs.

**Interfaces:**
- Consumes: `docs/assets/abigent-beta2-overview.png` and public Beta 2 URLs.
- Produces: the first-screen version callout, download links, and product screenshot.

- [ ] **Step 1: Replace the existing standalone pet image with the Beta 2 callout**

Immediately after the introduction, insert:

```markdown
> [!IMPORTANT]
> **当前推荐版本：[`v1.0.0-beta.2`](https://github.com/100656cyx/Abigent/releases/tag/v1.0.0-beta.2)**  
> Beta 1 存在 macOS 14 启动兼容问题，请下载 Beta 2。

[下载 Abigent v1.0.0-beta.2 DMG](https://github.com/100656cyx/Abigent/releases/download/v1.0.0-beta.2/Abigent-1.0.0-beta.2-macOS-arm64.dmg) · [查看发布说明](https://github.com/100656cyx/Abigent/releases/tag/v1.0.0-beta.2)

![Abigent 显示 Codex 完成状态、任务摘要和桌面小猫](docs/assets/abigent-beta2-overview.png)
```

Keep the free-signing warning directly below the screenshot.

- [ ] **Step 2: Validate README and repository hygiene**

```bash
git diff --check
test -f docs/assets/abigent-beta2-overview.png
rg -n 'v1\.0\.0-beta\.2|abigent-beta2-overview\.png|Beta 1 存在 macOS 14' README.md
git status --short
```

Expected: no whitespace errors; README contains the current version, compatibility warning, and screenshot path.

- [ ] **Step 3: Commit and push**

```bash
git add README.md docs/assets/abigent-beta2-overview.png docs/superpowers/plans/2026-08-09-github-homepage-beta2.md
git commit -m "docs: feature beta.2 on GitHub homepage"
git push origin main
```

- [ ] **Step 4: Verify the public homepage and download**

Confirm `https://github.com/100656cyx/Abigent` renders the screenshot and Beta 2 callout. Confirm the direct DMG URL responds successfully and still points to `Abigent-1.0.0-beta.2-macOS-arm64.dmg`.
