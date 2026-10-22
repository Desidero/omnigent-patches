<!-- Draft PR body for the new-chat-project-prompt series; title: feat(web): ask for a project when starting a new session -->
## Related issue

Closes #11083

## Summary

Depends on: palette-new-chat-in-project (stacked; would be rebased or split for upstream).

When you start a new session, the app now asks which project it belongs to first, so the session lands in the right place with that project's settings already filled in.

A project carries the settings a new session needs (host, workspace, agent, model, worktree), but every "new session" entry point opened a plain composer, so filing a session in its project and getting those defaults was an extra, easily forgotten step.

- When at least one project exists, the new-session hotkey, the sidebar's New session links (also reached from the mobile drawer) and the palette's New chat open the command palette on a "Start a new session in..." step: No project first, then every project, filtered by name as you type.
- Picking a project opens `/?project=<name>`, the route the per-project pencil already uses; No project opens the plain composer.
- Modified clicks (Cmd/Ctrl/middle click) on the sidebar links still open the composer in a new tab.
- Settings > General > Sessions gains "Ask for a project when starting a session" (on by default, stored per browser) to turn the prompt off.
- `feature-map/composer.md` documents the new `new-session-project-prompt` sub-feature.

## Test Plan

Tests added or changed:

- `web/src/shell/CommandPalette.test.tsx`: project step offers No project first then every project, filters by name, and New chat routes through `onNewSession`.
- `web/src/shell/AppShell.test.tsx`: asks for a project before opening the composer; opens it directly when the prompt is off.
- `web/src/shell/Sidebar.test.tsx`: New session links hand off to the prompt; modified clicks keep the new-tab behaviour.
- `web/src/hooks/useNewSessionHotkey.test.tsx`: the shortcut calls `onNewSession` instead of navigating.
- `web/src/lib/newChatProjectPromptPreferences.test.ts`: defaults on when unset; persists off and restores the default when cleared.

```sh
cd web && pnpm exec vitest run src/shell/CommandPalette.test.tsx src/shell/AppShell.test.tsx \
  src/shell/Sidebar.test.tsx src/hooks/useNewSessionHotkey.test.tsx \
  src/lib/newChatProjectPromptPreferences.test.ts
cd web && pnpm exec tsc -b
```

Manual:

1. On a server with no projects, press Cmd+Shift+O (macOS) or Ctrl+Shift+O: the composer opens directly, as before.
2. Create two projects with different default agents. Press the hotkey again: a "Start a new session in..." picker opens with No project, then both projects.
3. Type part of a project name and press Enter: the URL is `/?project=<name>` and the composer shows its defaults. Repeat and choose No project: a plain composer opens.
4. Click New session in the sidebar (and from the mobile drawer on a narrow window): the same picker opens. Cmd/Ctrl-click it: the composer opens in a new tab without the picker.
5. Open the palette, pick New chat: the picker opens.
6. In Settings > General > Sessions, turn off "Ask for a project when starting a session"; repeat steps 2, 4 and 5 and confirm the composer opens directly.

## Demo

- [ ] Visual demo attached below
- [ ] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

- [ ] TODO: recording of the hotkey opening the project picker, filtering, and landing on the composer with project defaults (throwaway server, dummy projects)
- [ ] TODO: screenshot of the picker opened from the sidebar's New session link on a narrow (mobile drawer) window
- [ ] TODO: screenshot of the new switch in Settings > General > Sessions

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

Component tests cover each entry point (hotkey, sidebar links, palette action), the picker contents and filtering, and the opt-out preference. No browser E2E was added; the destination route `/?project=<name>` is unchanged.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [ ] No — no noteworthy user-facing change.
- [x] Yes — include the entry in the Changelog section.

## Changelog

Starting a new session asks which project it belongs to and opens the composer with that project's defaults; turn it off in Settings > General > Sessions
