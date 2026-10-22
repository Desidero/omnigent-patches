<!-- Draft PR body for the session-labels-ui series; title: feat(web): view and edit session labels, and default labels per project -->
## Related issue

Closes #TODO (issue drafted in `proposals/session-labels-ui/issue.md`, not yet filed)

## Summary

Depends on: subscription-accounts (stacked; would be rebased or split for upstream).

Sessions can carry your own tags (labels such as `team: ml`), but the web UI never showed them. This PR lets you see and edit a session's labels, set them before a session starts, and give a project default labels that its new sessions receive.

Before this change the web UI had no way to see or change labels, a label could not be deleted through the API (PATCH only merges), and projects had no way to tag the sessions created in them.

Server:

- `PATCH /v1/sessions/{id}` deletes a label whose value is `null`. Reserved and `cost_control.*` keys are rejected for a delete exactly as for a set; the existing empty-string clear for `omni_project` and the pin key is unchanged.
- Creating a session in a project merges the project's `config.labels` under the request's labels (request wins). Internal, over-length and non-string entries are skipped, and the merged set still passes the reserved-label checks. Imports into a project get them too. Defaults apply only at creation, not when a session is moved into a project later.
- A create with `apply_project_labels: false` takes its labels as the final set, so a default removed for one session is not added back.

Web:

- A Labels section in the session info popover lists user labels and, with edit access, adds, edits and removes them, with inline validation against the key (128) and value (256) column widths. Internal labels (`omnigent.*`, `cost_control.*`, `omni_project`) stay hidden.
- Project settings gain a "Default labels" editor (same `LabelEditor` component), stored as `config.labels`. A label still typed in the add row is saved with the dialog, an invalid one blocks Save with its inline message, and closing the dialog with unsaved label changes warns once.
- The project settings dialog is capped to the viewport (85dvh): fields scroll while the header and Save/Cancel stay visible, since the labels editor made it taller than short windows. Upstream PR #5194 targets the same problem; whichever lands first, the other can drop its copy.
- The new-session composer's "+" menu gains Labels, opening the same editor for the session about to be created, with or without a project. Project defaults are filled in, marked "from project", and removable for that session only. The labels show as chips in the composer and go with the create request.
- The session list-cache overlay is shared by title, archive and label updates.
- `feature-map/sessions.md` documents the `labels` sub-feature; `openapi.json` is regenerated.

## Test Plan

Tests added or changed:

- `tests/server/routes/test_sessions_crud.py`, `tests/server/routes/test_sessions_cost_labels.py`: null deletes a label; reserved and `cost_control.*` deletes are rejected.
- `tests/server/routes/test_session_create_project_consistency.py`: project defaults merged at create (request wins), invalid entries skipped, imports, `apply_project_labels: false`.
- `web/src/components/AgentInfo.test.tsx`: Labels section, edit/remove, view-only collaborator.
- `web/src/shell/ProjectSettingsDialog.test.tsx`: Default labels editor, pending add-row saved, invalid label blocks Save, unsaved-changes warning.
- `web/src/shell/NewChatDialog.test.tsx`, `web/src/shell/NewChatDialog.projectCreate.test.tsx`: composer "+" > Labels, project defaults removable per session, labels sent with create.
- `web/src/lib/sessionLabels.test.ts`, `web/src/lib/sessionListCache.test.ts`: validation, internal-label filtering, cache overlay.

```sh
uv run pytest tests/server/routes/test_sessions_crud.py tests/server/routes/test_sessions_cost_labels.py \
  tests/server/routes/test_session_create_project_consistency.py
cd web && pnpm exec vitest run src/components/AgentInfo.test.tsx src/shell/ProjectSettingsDialog.test.tsx \
  src/shell/NewChatDialog.test.tsx src/shell/NewChatDialog.projectCreate.test.tsx \
  src/lib/sessionLabels.test.ts src/lib/sessionListCache.test.ts
cd web && pnpm exec tsc -b
```

Manual:

1. Open a session and click the header's info icon (on mobile, header menu > Agent info). Add `team: ml`, reload, and confirm it is kept. Edit it, then remove it and confirm it is gone after reload.
2. Try a 129-character key: the inline error appears and the label is not saved.
3. As a view-only collaborator, confirm the labels are listed without controls.
4. Open a project's three-dot menu > Project settings > Default labels, add `cost_center: research`, Save. Start a session in that project and confirm the label in its info popover.
5. Start another session in the project from the composer: "+" > Labels shows `cost_center` marked "from project". Remove it, add `ticket: 42`, start the session, and confirm only `ticket: 42` is in its popover.
6. Move an existing session into the project and confirm it gains no labels.
7. In Project settings, add a label and close the dialog without saving: a one-time warning appears. Shrink the window height and confirm Save/Cancel stay visible.
8. API: `curl -X PATCH .../v1/sessions/<id> -d '{"labels": {"team": null}}'` removes the label; `{"labels": {"omnigent.x": null}}` is rejected.

## Demo

- [ ] Visual demo attached below
- [ ] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

- [ ] TODO: recording of adding, editing and removing a label in the session info popover (throwaway server, dummy labels)
- [ ] TODO: screenshot of Project settings > Default labels, including an inline validation error
- [ ] TODO: screenshot of the composer "+" > Labels editor with a "from project" label and the resulting chips
- [ ] TODO: screenshot of the project settings dialog on a short window with the footer still visible
- [ ] TODO: curl output of a null-value PATCH removing a label

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

Server route tests cover deletion and project defaults; component tests cover the three editors. There is no browser E2E for the labels journey; the manual steps above cover it end to end.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [ ] No — no noteworthy user-facing change.
- [x] Yes — include the entry in the Changelog section.

## Changelog

View, add, edit and remove session labels in the web UI, set them when starting a session, and give projects default labels for their new sessions
