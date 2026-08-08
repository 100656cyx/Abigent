# Codex App Server Schema Verification

- Checked: 2026-08-08
- Local CLI: `codex-cli 0.147.0-alpha.6.5`
- Command: `codex app-server generate-json-schema --experimental --out <temporary-directory>`
- v2 bundle SHA-256: `a14d4878fe7b8cdd31059dbca11d7167d8cfd06effa2f7991b5364439063a5c8`

The installed schema explicitly contains `thread/list`, `thread/read`, `turn/start`, `turn/interrupt`, `turn/started`, `turn/completed`, `item/completed`, `item/commandExecution/requestApproval`, and `item/tool/requestUserInput`.

Abigent does not vendor the generated schema. It decodes only the fields required by the unified task model and ignores unknown notification methods. The connector must repeat this check whenever support for a new Codex CLI version is added.
