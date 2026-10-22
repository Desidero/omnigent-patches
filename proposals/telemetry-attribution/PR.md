<!-- Draft PR body for the telemetry-attribution series; title: feat(telemetry): attribute spans to the acting user and runner -->

## Related issue

Closes #10794

## Summary

On a multi-user server, exported spans only carried `session.id`, so answering "whose traffic is this?" or "which runner is slow?" meant joining against the Omnigent database. The user and runner are already bound in the debug-logging context on every request. This PR stamps them on spans too, the same way `session.id` and `omnigent.skill.active` are stamped.

- **`omnigent.runner.id`**: the runner bound to the request or lifecycle scope, falling back to `OMNIGENT_RUNNER_ID` in runner and harness processes (`omni-runner`, `omni-harness`). On whenever telemetry is enabled, since a runner id is not personal data. Adds a small `debug_logging.current_runner_id()` accessor.
- **`enduser.id`** (OTel semantic convention): the authenticated user on the server, and the process owner on host, runner and harness. Opt-in via `OMNIGENT_OTEL_CAPTURE_USER`, because the id is usually an email. The server's root HTTP span starts before auth resolves the user, so the middleware also sets it on that span once the user is known.
- **`OMNIGENT_OTEL_LOCAL_USER`**: with user capture on, reports the single-user `local` identity under this name, so solo installs that export to a shared collector stay attributable.
- Both variables are documented in `designs/OBSERVABILITY.md`.

The issue also proposes `omnigent.host.id` as a resource attribute on the host and its children. That is not in this PR and can follow separately.

## Test Plan

```sh
uv run pytest tests/runtime/test_telemetry.py
```

New tests: the runner processor prefers the bound runner and falls back to `OMNIGENT_RUNNER_ID` only in runner processes; the user processor stamps `enduser.id` only when opted in and maps `local` to `OMNIGENT_OTEL_LOCAL_USER`; `set_request_user` stamps the current server span only when opted in; `init` reads both new variables.

Manual, with a local OTLP collector (for example Jaeger all-in-one on port 4317):

1. Start the server and a host with `OMNIGENT_TELEMETRY_ENABLED=true` and `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317`, without `OMNIGENT_OTEL_CAPTURE_USER`.
2. Run a turn in a session. Server spans for that session's requests and the runner/harness spans carry `omnigent.runner.id`, and none carry `enduser.id`.
3. Restart with `OMNIGENT_OTEL_CAPTURE_USER=true`. The root `GET /v1/sessions` HTTP span and its children carry `enduser.id` set to the signed-in user.
4. On a single-user install, also set `OMNIGENT_OTEL_LOCAL_USER=alice@example.com`. Spans show `enduser.id=alice@example.com` instead of `local`.

## Demo

- [ ] Visual demo attached below
- [x] Non-visual evidence provided below or in Test Plan
- [ ] Not applicable — no behavioral change

- [ ] TODO: attach a span's attribute list from the collector (dummy user), once with user capture off (runner id only) and once on (runner id and `enduser.id`)

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

The processors and the server-span hook are tested against an in-memory span exporter. The collector check above is the end-to-end confirmation.

## Release notes

Should this change be included in the release notes? Choose exactly one.

- [x] No — no noteworthy user-facing change.
- [ ] Yes — include the entry in the Changelog section.
