<!-- Draft PR body for the sidebar-attention-filter series; title: feat(web): filter the sidebar to sessions that need you or changed recently -->

## Related issue

Closes #TODO (issue to be opened)

## Summary

Two new options in the sidebar's filter menu: show only sessions waiting on you, and show only sessions updated in the last day, week or month.

The sidebar lists every session and every project folder, so the few sessions waiting on you get lost. The status grouping can surface them, but it sits behind a release flag and drops the project folders.

This PR adds two device-local filters to the sessions filter menu, next to the My / Shared / All / Archived scope and independent of the grouping flag:

- **Needs me**: sessions with a pending approval or unread agent output, using the same read state as the unread dot. A failure you have already seen doesn't count.
- **Updated**: Any time / Last 24 hours / Last 7 days / Last 30 days. These are rolling windows rather than calendar days, so the shortest one doesn't empty out just after midnight.

While either filter is on:

- project folders with nothing matching are hidden (except the one the composer targets);
- the filter icon is highlighted and empty states say "No matching sessions" / "No matching projects";
- the open session stays listed, so reading it doesn't remove it from the list;
- project reordering and infinite scroll inside folders pause, since they work on the full lists.

Pins are unaffected, as with the scope filter. The choice is stored per device in `web/src/lib/sidebarFocusPreferences.ts`, and the matching rule lives in `matchesSidebarFocus` in `sidebarNav.ts`.

## Test Plan

```sh
cd web && pnpm exec vitest run src/lib/sidebarFocusPreferences.test.ts \
  src/shell/sidebarNav.test.ts src/shell/Sidebar.test.tsx
cd web && pnpm exec tsc -b
```

The tests cover the stored preference (defaults, round trip, corrupt values), the matching rule (pending approvals and unseen output count, seen failures don't, the rolling window just after midnight, both filters together), and a sidebar render where Needs me keeps approval and unread sessions and hides folders with neither.

Manual, on a throwaway server with dummy sessions:

1. Create a few sessions, some in projects. Leave one with a pending approval and one with an unread reply, and read the rest.
2. Open the sidebar's filter menu and tick **Needs me**. Only the approval and unread sessions remain, folders with neither disappear, and the filter icon is highlighted. Pinned sessions stay.
3. Open one of the remaining sessions. It stays in the list after being read. Switch to another session; the read one drops out.
4. Untick Needs me and set **Updated › Last 24 hours**. Only sessions active in the last 24 hours are listed.
5. Reload the page. The filter is still set. Set it back to Any time and every session and project folder returns.

## Demo

- [x] Visual demo attached below
- [ ] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

To capture on a clean throwaway server with dummy sessions and projects:

- [ ] TODO: screenshot of the filter menu showing Needs me and the Updated submenu
- [ ] TODO: before/after screenshots of the sidebar with Needs me on (folders without matches hidden, filter icon highlighted)
- [ ] TODO: short recording of opening a matching session, reading it, and moving on so it drops out of the filtered list

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

The filter logic and the sidebar render are covered by component tests. The manual steps check the live read-state updates, which the tests stub.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [ ] No — no noteworthy user-facing change.
- [x] Yes — include the entry in the Changelog section.

## Changelog

Filter the sidebar to sessions that need you, or to sessions updated in the last 24 hours, 7 days or 30 days
