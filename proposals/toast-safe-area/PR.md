<!-- Draft PR body for the toast-safe-area series; title: fix(web): keep toasts below the iOS status bar and Dynamic Island -->

## Related issue

Closes #TODO (issue to be opened)

## Summary

In the iOS app, toasts appeared under the status bar and Dynamic Island, where they couldn't be read.

The toaster renders top-center with sonner's fixed top gap (24px desktop, 16px mobile). Its bottom edge already clears the home indicator via `--omnigent-inset-bottom`. This change adds the matching `--omnigent-inset-top` to the top offset in `web/src/shell/AppShell.tsx`. Desktop and Android, which have no top inset, keep sonner's default gaps.

## Test Plan

This is a three-line CSS offset change with no unit test. Verify it by eye:

```sh
cd web && pnpm exec tsc -b
cd web && pnpm exec vitest run src/shell/AppShell.test.tsx
```

Manual:

1. Build the iOS app against a test server and open it on an iPhone with a Dynamic Island, or a simulator such as iPhone 15 Pro.
2. Trigger a toast, for example by saving an agent under Settings ("Agent saved") or copying text from the Terminal view ("Copied from terminal."). The toast sits fully below the status bar and Dynamic Island.
3. Open the web UI in a desktop browser and trigger the same toast. Its position is unchanged (24px from the top).
4. In the desktop browser's mobile emulation (no safe-area inset), the toast sits 16px from the top as before.

## Demo

- [x] Visual demo attached below
- [ ] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

To capture on a clean throwaway server:

- [ ] TODO: before/after screenshots of a toast in the iOS app on a Dynamic Island device or simulator
- [ ] TODO: screenshot of the same toast on desktop, showing no change

## Type of change

- [x] Bug fix
- [ ] Feature
- [x] UI / frontend change
- [ ] Refactor / chore
- [ ] Docs
- [ ] Test / CI
- [ ] Breaking change

## Test coverage

- [ ] Unit tests added / updated
- [ ] Integration tests added / updated
- [ ] E2E tests added / updated
- [ ] Manual verification completed
- [ ] Existing tests cover this change
- [x] Not applicable

## Coverage notes

The change only adds the safe-area inset to the toaster's top offset. jsdom doesn't lay out or resolve safe-area variables, so a unit test would only restate the prop. TODO before opening: run the manual steps on a Dynamic Island device and on desktop, attach the screenshots, then tick Manual verification.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [x] No — no noteworthy user-facing change.
- [ ] Yes — include the entry in the Changelog section.
