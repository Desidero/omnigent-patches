<!-- Draft PR body for the gateway-request-tags series; title: feat(harnesses): tag Unity Gateway requests with the session's labels -->
## Related issue

Closes #TODO (issue drafted in `proposals/gateway-request-tags/issue.md`, not yet filed)

## Summary

Depends on: chat-item-labels (stacked; would be rebased or split for upstream).

Every request Omnigent sends through a Databricks Unity Gateway now carries the session id and the session's labels, so gateway usage and inference logs can be grouped by session, project or team.

Unity Gateway logs a per-request `Databricks-Ai-Gateway-Request-Tags` header (a JSON object of string tags) in the `request_tags` column of its usage tracking and inference tables. Omnigent forwarded no session information to any provider, so gateway usage could not be joined back to the session or its labels.

- When a harness targets a Unity Gateway URL (same `is_databricks_ai_gateway_url` gate as the attribution headers), its requests carry the header with `omnigent_session_id` plus the session's user labels. Omnigent-owned labels (`omnigent.*`, `cost_control.*`, `omni_project`) are skipped. The value is compact ASCII JSON; past 8 KiB labels are dropped in key order while the session id is always kept. Other gateways and providers never get the header.
- `OMNIGENT_GATEWAY_REQUEST_TAGS=0` turns it off. The host daemon forwards it to runners and `omnigent host enable` keeps it in the service definition.
- `omnigent/databricks_ai_gateway.py`: header name, tag builder, opt-out switch, and dict / `ANTHROPIC_CUSTOM_HEADERS` helpers, next to the attribution helpers.
- claude-native: CLI and runner launch paths append the tags to `ANTHROPIC_CUSTOM_HEADERS` on gateway launches.
- claude-sdk, codex, pi: the runner hands the encoded tags to the harness process in `OMNIGENT_GATEWAY_REQUEST_TAGS_VALUE` (from envelope labels, or one label fetch for harnesses that may reach a gateway). claude-sdk and pi add the header on gateway providers (pi with its `$` template escape); Codex gateway providers map it through `env_http_headers`.
- codex-native: the app-server env carries its own session's tags, from the runner's launch snapshot or the CLI's session fetch.
- Native CLIs and harness processes read the tags at launch, so a label edit reaches the header after the next launch or respawn.
- `docs/databricks.md` gains a "Session request tags" section and an env-var table row.

## Test Plan

Tests added or changed:

- `tests/test_databricks_ai_gateway.py`: tag builder, internal-label filtering, 8 KiB cap keeping the session id, opt-out, header helpers.
- `tests/runner/test_runner_dispatch.py`, `tests/runner/test_app_claude_native_launch_args.py`, `tests/runner/test_codex_native_launch_config.py`, `tests/runner/test_app_sessions_native_terminals_runtime.py`: runner passes tags only for gateway targets.
- `tests/inner/test_claude_sdk_executor.py`, `tests/inner/test_codex_executor.py`, `tests/inner/test_pi_executor.py`: per-harness header wiring, including pi's `$` escape.
- `tests/harnesses/codex_native/app_server/test_launch_config.py`, `tests/cli/test_host_daemon_env.py`: codex-native app-server env and host env forwarding of the opt-out.

```sh
uv run pytest tests/test_databricks_ai_gateway.py tests/runner/test_runner_dispatch.py \
  tests/runner/test_app_claude_native_launch_args.py tests/runner/test_codex_native_launch_config.py \
  tests/runner/test_app_sessions_native_terminals_runtime.py tests/inner/test_claude_sdk_executor.py \
  tests/inner/test_codex_executor.py tests/inner/test_pi_executor.py \
  tests/harnesses/codex_native/app_server/test_launch_config.py tests/cli/test_host_daemon_env.py
```

Manual (needs a Unity Gateway endpoint):

1. Configure a claude-native (or codex / pi) agent to use a Unity Gateway URL. Create a session and give it a label, e.g. `team: ml` (`PATCH /v1/sessions/{id}`).
2. Restart the harness (new session or respawn) and send a turn.
3. Query the gateway's usage tracking or inference table: the row's `request_tags` holds `{"omnigent_session_id": "<id>", "team": "ml"}` and no `omnigent.*` / `omni_project` keys.
4. Point the same agent at a non-gateway provider and confirm (e.g. with a local logging proxy) no `Databricks-Ai-Gateway-Request-Tags` header is sent.
5. Set `OMNIGENT_GATEWAY_REQUEST_TAGS=0` in the host daemon env, restart the host, start a new session, and confirm the header is gone.

## Demo

- [ ] Visual demo attached below
- [ ] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

- [ ] TODO: redacted query output from a scratch gateway's usage table showing `request_tags` with the session id and a dummy label
- [ ] TODO: redacted header dump from a local logging proxy showing the header absent for a non-gateway provider and with the opt-out set

## Type of change

- [ ] Bug fix
- [x] Feature
- [ ] UI / frontend change
- [ ] Refactor / chore
- [x] Docs
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

Unit tests cover the tag builder and each harness's launch wiring with stubbed providers. Verifying the logged `request_tags` needs a real Unity Gateway endpoint and is listed under the manual steps.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [ ] No — no noteworthy user-facing change.
- [x] Yes — include the entry in the Changelog section.

## Changelog

Requests sent through a Databricks Unity Gateway carry the session id and session labels as request tags, so gateway usage can be grouped by session; set `OMNIGENT_GATEWAY_REQUEST_TAGS=0` to opt out
