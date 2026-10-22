<!-- Draft PR body for the claude-native-teammates series; title: fix(claude-native): register agent-team teammates as child sessions -->
## Related issue

Closes #10745

## Summary

Claude Code agent-team teammates now show up in Omnigent like every other Claude sub-agent, and their messages to the team lead no longer appear in the lead's chat as raw markup.

**Teammates as child sessions.** In-process teammates run inside the lead's Claude process and write `agent-<id>.meta.json` with `taskKind: "in_process_teammate"` and no `toolUseId`. The forwarder required a `toolUseId`, so teammates were never registered: they were missing from the Agents rail, their transcripts were not mirrored or counted in the parent's real-time cost estimate, and each unregistered meta kept the forwarder re-reading every transcript on every poll. Now:

- A teammate meta is registered under the lead session without spawn correlation. Its description leads with the teammate's `name` (the handle the lead messages it by), e.g. `differ: Version-diff pass on findings`.
- The start event carries a stable `teammate:<id>` tool-use id, which the server already accepts unchanged; no real spawn record can match it.
- Metas are read before correlating, so a poll that sees only teammate (or unreadable) metas skips the transcript scan.
- A meta missing `toolUseId` for any other reason is still skipped.

**Teammate deliveries in the lead's chat.** Claude Code delivers a teammate's message to the lead as a plain user record framed "Another Claude session sent a message:" plus a `<teammate-message>` envelope and its own guidance paragraph, with no `origin` field. The bridge only trusted `origin.kind == "peer"`, so these were persisted as user-authored and rendered as raw markup and `idle_notification` JSON. Typed and pasted prompts carry `origin: {"kind": "human"}` (both as user records and as prompts queued mid-turn), so a record or queued prompt with no `origin` and Claude's complete framing, with nothing else in the text, is now treated as internal like other peer traffic. Human-origin input, and framing with extra text, still render as the user's message.

## Test Plan

Tests added or changed:

- `tests/harnesses/claude_native/forwarder/test_subagent_discovery.py::test_subagent_watcher_registers_an_in_process_teammate_under_the_lead`: the teammate registers under the lead with the `teammate:<id>` id and named description, without a transcript scan; a meta without `toolUseId` and without the teammate kind stays unregistered.
- `tests/harnesses/claude_native/test_claude_native_bridge.py`: `test_claude_framed_delivery_without_origin_is_internal` (full framing hidden; bare envelope or framing plus extra text stays visible), `test_queued_framed_delivery_from_a_human_stays_visible`, a queued framed delivery case in the existing hidden-prompt matrix, and `test_team_markup_needs_provenance` now passes the human origin Claude stamps on typed prompts.

```sh
uv run pytest tests/harnesses/claude_native/forwarder/test_subagent_discovery.py tests/harnesses/claude_native/test_claude_native_bridge.py
```

Manual:

1. Enable Claude Code agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) and start a claude-native session.
2. Ask: "Create a team with two teammates named alpha and beta. Have each count to three, message you the result, then stop."
3. The Agents rail lists `alpha: ...` and `beta: ...` as children of the session; opening one shows its mirrored transcript.
4. The lead's chat shows no "Another Claude session sent a message:" text, `<teammate-message>` markup or `idle_notification` JSON.
5. Type the framed text by hand ("Another Claude session sent a message: hello") into the lead: it still renders as your message.
6. Check runner logs while the team is idle: the forwarder no longer rescans transcripts on every poll for the teammate metas.

## Demo

- [ ] Visual demo attached below
- [ ] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

- [ ] TODO: screenshot of the Agents rail listing two teammates under the lead (throwaway server, dummy team task)
- [ ] TODO: before/after screenshot of the lead's chat, showing raw teammate markup before and a clean transcript after

## Type of change

- [x] Bug fix
- [ ] Feature
- [ ] UI / frontend change
- [ ] Refactor / chore
- [ ] Docs
- [ ] Test / CI
- [ ] Breaking change

## Test coverage

- [x] Unit tests added / updated
- [ ] Integration tests added / updated
- [ ] E2E tests added / updated
- [ ] Manual verification completed
- [ ] Existing tests cover this change
- [ ] Not applicable

## Coverage notes

The forwarder test drives `_forward_available_subagents` against a mocked server and asserts the transcript scan is skipped; the bridge tests cover both string and block content for records and queued prompts. Agent teams are an experimental Claude Code feature, so there is no CLI-driven E2E.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [ ] No — no noteworthy user-facing change.
- [x] Yes — include the entry in the Changelog section.

## Changelog

Claude Code agent-team teammates appear as child sessions in the Agents rail, and their messages to the team lead no longer show as raw markup in chat
