# Stop-Anchored Result Recovery Design

## Goal

Prevent a newly started Codex turn from stealing result extraction while Abigent is still recovering the result of the turn that just emitted `Stop`.

## Design

`CodexResultExtractor` will parse each JSONL event timestamp and group events into turns. When a Hook `Stop` event supplies `stopObservedAt`, extraction selects the newest turn that started no later than that timestamp. Events belonging to a later turn are excluded even if retrying occurs after that later turn has already begun.

For legacy or synthetic JSONL records without timestamps, the extractor retains the existing latest-turn behavior. This keeps older session formats and existing tests compatible.

The recovery coordinator continues retrying delayed file writes. Its retry target remains stable because every attempt receives the same `stopObservedAt` anchor.

## Error Handling

- Invalid session identifiers and missing session files retain their existing errors.
- If the anchored turn has no non-empty assistant message yet, extraction returns `resultNotYetAvailable` so the coordinator retries.
- Malformed JSONL lines remain ignorable.
- A turn starting after the Stop timestamp must never cause the preceding result to disappear.

## Verification and Release

- Add a regression fixture with a completed turn, a Stop timestamp, and a newer incomplete turn.
- Verify the completed turn's final response is returned.
- Run the complete Swift test suite.
- Build and verify an arm64 free-signing DMG as `v1.0.0-beta.3`.
- Update public download guidance and publish the tag, source, release notes, DMG, and checksum to GitHub.
