<!-- Draft PR body for the web-reconnect-shell-inputs series; title: fix(web): settle queued !cmd bubbles a reconnect recovers -->
## Related issue

Closes #TODO (issue to be opened)

## Summary

If the connection dropped while a `!command` was waiting or running, its "queued" bubble stayed stuck at the bottom of the chat after reconnecting, even though the command had run. It now clears on reconnect.

A `!cmd` sent to a claude-native or codex-native session gets no `session.input.consumed` receipt; its queued bubble clears only when the live `terminal_command` item event arrives. If the stream drops while the command waits or runs (a phone locks, a laptop sleeps, a proxy recycles the connection), that event fires into the dead socket. The reconnect backfill then splices the committed `terminal_command` item into the transcript, but it only acknowledges recovered user messages, so the bubble stayed pinned until a full reload.

- Both reconnect paths (the incremental backfill and the fresh-window fallback) now settle the bubbles of recovered shell inputs, using the same command match and per-item dedupe as the live handler. The live handler and both paths share one helper, `settleShellInput`.
- Shell bubbles are settled before the user-message FIFO acknowledgement, so that count no longer lands on a shell bubble.
- A replay of the same item on the new stream does not settle a second identical command.

## Test Plan

Tests added: `web/src/store/chatStore.test.ts` ("settles a queued !cmd bubble whose shell input the reconnect recovers through ordinary backfill / the fresh-window fallback"), which drops the stream while a shell input commits, checks only the matching bubble is settled, and replays the item to check the identical second command stays queued.

```sh
cd web && pnpm exec vitest run src/store/chatStore.test.ts
cd web && pnpm exec tsc -b
```

Manual:

1. Open a claude-native session in the web UI and send `!sleep 30 && echo done`.
2. While it runs, cut the stream: put the laptop to sleep or lock the phone for about 40 seconds, or in desktop devtools set the network to Offline and back.
3. When the page reconnects, the shell output appears in the transcript and the queued `!sleep ...` bubble is gone without a reload.
4. Send the same command twice in a row, drop the connection during the first, reconnect: only the first bubble clears; the second stays queued until it runs.
5. Repeat step 1-3 in a codex-native session.

## Demo

- [ ] Visual demo attached below
- [ ] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

- [ ] TODO: before/after recording of a `!sleep 30` command across a forced offline/online toggle, showing the stuck bubble before and the cleared bubble after (throwaway server, dummy session)

## Type of change

- [x] Bug fix
- [ ] Feature
- [x] UI / frontend change
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

The store test drives the real reconnect loop (`startStreamPump`) through both backfill paths with a seeded gap, so it covers the dropped-event case end to end within the client.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [x] No — no noteworthy user-facing change.
- [ ] Yes — include the entry in the Changelog section.
