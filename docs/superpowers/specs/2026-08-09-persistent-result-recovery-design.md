# Persistent Per-Turn Result Recovery Design

## Goal

Recover a Codex final response even when the session JSONL is flushed late, without one turn cancelling another turn in the same session.

## Design

`CodexResultRecoveryCoordinator` identifies recovery work by `(sessionID, stopObservedAt)` instead of `sessionID`. Duplicate recovery requests for the same Stop are deduplicated; different Stops in the same session remain independent.

The existing fast retry schedule remains for normal writes. After that schedule is exhausted, recovery repeats its final interval for up to about ten minutes. Every retry uses the original Stop timestamp, so a later turn cannot change the extraction target.

An old result delivered after a newer turn starts is already rejected by `TaskReducer` because its observed timestamp precedes the current Hook event. This preserves the latest task state and prevents stale summaries.

## Verification and Release

- Test that two Stops in one session can both finish.
- Test that recovery continues beyond the initial delay schedule.
- Run the full GitHub Xcode CI suite and package checks.
- Release as `v1.0.0-beta.4` and update the local app.
