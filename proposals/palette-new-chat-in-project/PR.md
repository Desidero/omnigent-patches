<!-- Draft PR body for the palette-new-chat-in-project series; title: feat(web): start a new chat in a project from the command palette -->
## Related issue

Closes #4409

## Summary

The palette's "New chat" always opens a plain composer, so starting a session with a project's stored defaults (host, workspace, agent, model, worktree) meant leaving the keyboard for the per-project pencil in the sidebar.

- Typing in the command palette now also lists "New chat in <project>" rows. Picking one opens the composer at `/?project=<name>`, the same route the sidebar pencil uses.
- Every typed word must appear in the row label, so "new omni" and "omni" both match.
- The rows stay hidden while the query is empty, so a long project list does not push Actions out of view, and the sessions-only switcher leaves them out.

## Test Plan

- `web/src/shell/CommandPalette.test.tsx` gains four cases: rows hidden until the user types, every typed word matched against the label, picking a row navigates to `/?project=<name>` and closes the palette, and the sessions-only switcher omits the rows.

```sh
cd web && pnpm exec vitest run src/shell/CommandPalette.test.tsx
cd web && pnpm exec tsc -b
```

Manual:

1. Create two projects, e.g. `alpha` and `beta lab`, with different default agents or workspaces.
2. Open the command palette (Cmd/Ctrl+K) with an empty query: no "New chat in ..." rows appear.
3. Type `beta`: "New chat in beta lab" appears. Type `new beta`: it still matches. Type `new gamma`: it disappears.
4. Pick "New chat in beta lab": the URL is `/?project=beta%20lab` and the composer shows that project's defaults.
5. Open the sessions-only switcher and type `beta`: no project rows appear.

## Demo

- [ ] Visual demo attached below
- [ ] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

- [ ] TODO: screenshot of the palette with a typed query showing "New chat in <project>" rows (throwaway server, dummy projects)
- [ ] TODO: short recording of picking a row and landing on the composer with the project's defaults

## Type of change

- [ ] Bug fix
- [x] Feature
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

Component tests cover filtering, navigation and the sessions-only switcher. No browser E2E: the navigation target is the existing `/?project=<name>` route, which already has coverage.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [x] No — no noteworthy user-facing change.
- [ ] Yes — include the entry in the Changelog section.
