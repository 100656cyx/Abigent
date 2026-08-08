# Codex Live Connection Check

Date: 2026-08-08  
Codex CLI: `0.147.0-alpha.6.5`  
Codex desktop bundle: `com.openai.codex`, version `26.803.41515` (6321)

## Redaction rules

The diagnostic output contains only timestamps, event categories, normalized states, counts, and SHA-256 hashes of source task IDs. It does not print thread titles, prompts, responses, repository paths, account identifiers, or tokens.

## Results

| Capability | Result | Evidence |
|---|---|---|
| Initialize local App Server | Pass | `doctor` completed the JSON-RPC initialize handshake. |
| Discover existing Codex threads | Pass | `thread/list` returned 20 locally stored threads. |
| Detect active state of threads running in Codex desktop | Not available through a second App Server | A 10-second watch received connector lifecycle only; list results were not loaded into the diagnostic App Server runtime. |
| Read completion result | Protocol mapping implemented; live desktop result still needs a shared-runtime or UI bridge | `thread/read` and `turn/completed` are present in the generated v2 schema. |
| Reply to desktop approval or user-input request | Requires limited fallback | Server-request reply routing is implemented, but the desktop App Server is attached to the desktop process over stdio and exposes no documented attach socket. |
| Open exact task in Codex | Unverified | The app registers the `codex` URL scheme, but no supported thread deep-link shape has been established. |

## Runtime inspection

Codex desktop launches its own process as:

```text
codex -c features.code_mode_host=true app-server --analytics-default-enabled
```

That App Server is attached to the desktop process over inherited stdio. The visible `~/.codex/ipc/ipc.sock` is owned by the desktop shell, not advertised by `codex app-server` as a public control socket. Abigent will not depend on this private IPC format.

## Gate decision

`GO_WITH_LIMITED_ACCESSIBILITY_FALLBACK`

Use App Server/state storage for automatic discovery, structured history, independently hosted Codex tasks, and protocol-compatible result parsing. Use a narrowly scoped, explicitly authorized macOS Accessibility bridge for live desktop state, exact task navigation, and desktop-owned prompt interaction. Do not use screen-coordinate or pixel recognition. Keep unknown desktop states as `connectionUnknown` rather than inventing progress.

The bounded fallback is implemented behind an explicit `enabled` preference and trust check. It locates Codex by bundle identifier, searches the accessibility tree by roles and labels, and exposes only visible-state, focus-task, choice, and text-response operations. Live granted-permission verification remains part of the native app onboarding test because the diagnostic executable must not trigger a system permission prompt on its own.
