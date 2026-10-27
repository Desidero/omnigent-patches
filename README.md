# omnigent-patches

Candidate contributions to [Omnigent](https://github.com/omnigent-ai/omnigent),
kept as a patch series until they land upstream, and the CI that builds and
releases Omnigent with them.

Each change here is meant to go upstream. Until it does, it lives in this
repository as a plain patch file, so you can read it, apply it to your own
Omnigent checkout, or take just the pieces you want. When a change merges
upstream, its patches are dropped from the series.

- `patches/BASE` is the upstream commit the series applies to.
- `patches/series` lists the patches in apply order, grouped into named
  series (`# series: <name>`). A `# needs: <name>` line means that series
  expects another one to be applied first.
- `patches/*.patch` are `git format-patch` files, one per commit, named
  `<series>--<subject>.patch`.
- `proposals/<series>/` holds the draft upstream PR description for each
  series (`PR.md`), a draft issue where one is useful (`issue.md`), and an
  `evidence/` folder for screenshots and logs to attach to the PR.
- `scripts/` builds, exports and checks the series.
- `release/` builds the install set and the server image, publishes
  releases, and installs a release on a host (`release/README.md`).

This repository is the source of truth. The `custom` branch on
[Desidero/omnigent](https://github.com/Desidero/omnigent/tree/custom) is
built from it by CI on every merge (upstream at `BASE` plus the whole series)
and is never edited by hand; each build is also a tagged
[release](https://github.com/Desidero/omnigent/releases) there.

## How a change gets in

```
develop on a working branch  ->  export to patch files  ->  pull request here
  (built with build-custom.sh)    (export.sh, check.sh)     (CI: apply, docs, tsc,
                                                             tests, install set)
        -> merge to main  ->  CI: fork custom branch, tag custom/<date>.<n>,
                              GHCR image, pre-release with the install set
```

Merging a pull request is the only way the series changes; an upstream
refresh is a pull request too (a new `BASE` plus the refreshed patches).

## Developing a change

The helpers take the Omnigent clone with `--repo` (or `$OMNIGENT_REPO`); it
needs upstream as a remote (`upstream` below).

1. **Build a working branch** from the series:
   `scripts/build-custom.sh --repo <clone> work/<topic>`. The commits are
   reproducible: the same `BASE` and patch files give the same commit ids
   everywhere (fixed committer, committer date = author date), so the branch
   matches what CI builds.
2. **Change it** like any branch: add commits, amend or `git rebase -i` the
   patch you are fixing (keep fixups squashed into the patch they fix), drop
   a patch that landed upstream. Develop the fix itself on a contribution
   branch cut from `upstream/main` when it is headed upstream, and cherry-pick
   it here. Try it with the repo's tests, or install the pull request's build
   (below).
3. **Export**: `scripts/export.sh --repo <clone> work/<topic> upstream/main`
   rewrites `patches/BASE`, `patches/series` and the patch files. Series are
   matched by each commit's subject; a new commit joins the previous commit's
   series with a warning, so move it in `patches/series` if it belongs
   elsewhere and run the export again. `# needs:` lines and other comments in
   a series are kept.
4. **Check**: `scripts/check.sh --repo <clone> --custom work/<topic>` applies
   the series in a throwaway worktree, runs the [docs rule](#docs-rule), a
   quick sanity check (no conflict markers, changed Python and JSON parse) and
   confirms the result has exactly your branch's tree.
5. **Open a pull request** with the regenerated files, plus
   `proposals/<series>/PR.md` for a new series and a fixup to the index
   (`docs/custom/README.md`, series `custom-docs-index`).

To try a pull request before it merges, download its `install-set-<build>`
artifact from the PR's `check` run (`gh run download <run-id> -R
Desidero/omnigent-patches -n install-set-<build>`) and install it like a
release (`release/README.md`).

### Refreshing the base

```bash
git -C <clone> fetch upstream
scripts/build-custom.sh --repo <clone> work/refresh
git -C <clone> rebase upstream/main work/refresh   # resolve; rerere remembers
scripts/export.sh --repo <clone> work/refresh upstream/main
scripts/check.sh --repo <clone> --custom work/refresh
```

Drop patches that landed upstream during the rebase. The pull request bumps
`BASE`, so CI runs the tests for every patch, not only the changed ones.

## What CI does

`.github/workflows/check.yml`:

| Event | Jobs |
| --- | --- |
| Pull request | `apply` (the required check: build with `build-custom.sh`, `check.sh --tree`, unit tests of `release/`, test selection), `web` (`tsc -b` and the selected vitest files), `python` (the selected pytest files), `package` (the install set as an artifact, the server image built and smoke-tested but not pushed; the release notes go to the job summary) |
| Push to `main` touching `patches/`, `release/` or the workflow | The same, then `publish`: force-updates the fork's `custom`, pushes the tag, pushes the image to GHCR and creates the release |
| Manual run | Dry run by default: everything, with `publish` printing the pushes, tag, image push and release instead of doing them. A real run needs `main` |

Test selection (`scripts/select-tests.py`): for each patch whose content
changed against the PR's base (by `git patch-id`, so a refresh that only
moves line numbers doesn't count), the touched test files, plus
`tests/**/test_<module>.py` and `test_<module>_*.py` for each touched Python
module, and for the web UI the touched `*.test.ts(x)` files and
`vitest related` on the touched sources. A moved `BASE` selects every patch.
Browser, live-server and benchmark lanes stay with upstream's CI.

The repositories default to `omnigent-ai/omnigent`, `Desidero/omnigent` and
`ghcr.io/desidero/omnigent-server`; the repository variables `UPSTREAM_REPO`,
`FORK_REPO` and `IMAGE_NAME` override them. Publishing needs the
`FORK_RELEASE_TOKEN` secret; `release/README.md` says how to make it.

## Releases

- **Tag** `custom/<YYYY-MM-DD>.<n>` on the fork, an annotated tag on the
  built custom commit, `n` counting from 1 per UTC day. Tags are never moved
  or reused: a re-run of the same build resumes its tag, anything else gets
  the next number. The date says how old a build is at a glance and sorts;
  the `custom/` prefix keeps it apart from upstream's version tags.
- **Version** `<upstream version>+oss<BASE:8>.p<patches commit:7>`, a PEP 440
  local version, e.g. `0.20.0.dev0+oss65be0f24.pf06503b`. It is stamped at
  build time with upstream's `scripts/update_versions.py`, so the custom
  branch keeps upstream's version files. `omnigent --version` prints it with
  the custom commit: `omnigent 0.20.0.dev0+oss65be0f24.pf06503b (5f8946ab, built …)`.
- **Release** on the fork, a pre-release by default; mark the one that goes
  to production as a full release later. Assets: the `omnigent`,
  `omnigent-client` and `omnigent-ui-sdk` wheels, `constraints.txt` (every
  dependency pinned to the build's `uv.lock`), the host scripts,
  `manifest.json` (commits, version, image, sha256 of every file, the series
  with patch ids) and `custom-docs.md`.
- **Image** `ghcr.io/desidero/omnigent-server:custom-<date>.<n>`
  (linux/amd64), built by `release/server.Dockerfile` from the same wheels
  and constraints, labelled with the version and the three commits.
- **Notes**: version, OSS base, patches commit, custom commit and image; the
  changes since the previous release (series added, changed or dropped, base
  moved), computed from the two manifests; and the series index with its
  links pinned to the tag. `custom-docs.md` bundles, per series, the doc
  sections its patches add or change.

### Docs rule

Every patch ships its own usage docs in the same commit, in upstream's places
(`docs/`, the matching `feature-map/` recipe, or for API and telemetry details
`omnigent/server/API.md` and `designs/`). A patch with nothing to document,
such as an internal fix or a refactor, says why in a `Docs: none (<reason>)`
trailer. The last commit, series `custom-docs-index`, is
`docs/custom/README.md`: one `## <series>` section per series saying what it
changes, how to turn it on and where its docs are; adding, changing or
dropping a patch includes a fixup to it. `scripts/check.sh` enforces all
three: docs or the trailer on every patch, a section for every series, and
`custom-docs-index` last. The release notes carry that index, and
`custom-docs.md` the docs themselves.

## Tracker

`tracker.yaml` records, per series and per upstream change we only watch, the
upstream issue and PR links plus relationships (`carries`, `blocked_by`,
`superseded_by`, `related`, `conflicts`). `scripts/tracker.py OUT.html` joins
it with `patches/series` and live GitHub state to produce a page with a drop
list (patches to remove on the next rebase), what waits on us, what waits on
maintainers, and a dependency graph. The table below is the hand-written
summary; the generated page is the live view.

## Patch index

Status is one of: **proposed** (not yet filed upstream; see `proposals/`),
**issue open** (an upstream issue tracks it), or **PR open** (an upstream pull
request carries it, and this repository holds a copy until it merges).

| Series | What it does | Status |
|---|---|---|
| `claude-config-dir` | claude-native and claude-sdk follow `CLAUDE_CONFIG_DIR` instead of assuming `~/.claude`. | PR open ([#9617](https://github.com/omnigent-ai/omnigent/pull/9617), carried copy) |
| `subscription-accounts` | Several Claude or Codex subscription logins per host: pick the account for a new session, switch a running session's account from the harness menu, accounts that share sessions through account tokens, and agents can start a child session on another account. Docs in `docs/providers.md`. Needs `claude-config-dir`. | issue open ([#503](https://github.com/omnigent-ai/omnigent/issues/503)) |
| `toast-safe-area` | Toasts stay below the iOS status bar and Dynamic Island. | PR open ([#11390](https://github.com/omnigent-ai/omnigent/pull/11390)) |
| `session-history-paging` | Agents can page through a session's history and list recently updated sessions. | proposed |
| `terminal-touch` | The terminal on phones and tablets: a Termux-style extra-keys row, long-press select, copy and paste, and native iOS clipboard reads for Paste. | PR open for the extra-keys row ([#6136](https://github.com/omnigent-ai/omnigent/pull/6136), carried copy with two iOS fixes); the rest proposed |
| `telemetry-attribution` | Exported spans carry the acting user (opt-in), the runner and the host. | PR open ([#11380](https://github.com/omnigent-ai/omnigent/pull/11380); issue [#10794](https://github.com/omnigent-ai/omnigent/issues/10794)) |
| `session-telemetry` | Every span of a turn carries the session's metadata (labels, project, agent, git, workspace, host) and the model and reasoning effort the turn ran with. | PR open ([#11384](https://github.com/omnigent-ai/omnigent/pull/11384), then [#11434](https://github.com/omnigent-ai/omnigent/pull/11434) stacked on it, draft) |
| `sidebar-attention-filter` | Sidebar filters for sessions that need you or changed recently. | proposed |
| `claude-sdk-web-tools` | claude-sdk agents can opt into Claude Code's WebSearch and WebFetch. | proposed |
| `run-suggested-commands` | A Run button on shell commands an agent suggests in chat. | proposed |
| `codex-native-shell-input` | A web `!command` runs as a Codex shell command instead of reaching the model as a prompt. Rides on `run-suggested-commands`, which carried the first version. | PR open ([#11396](https://github.com/omnigent-ai/omnigent/pull/11396)) |
| `claude-native-teammates` | Claude Code agent-team teammates show up as child sessions, and their deliveries no longer appear as raw `<teammate-message>` bubbles. | PR open ([#11388](https://github.com/omnigent-ai/omnigent/pull/11388) for the child sessions, [#11389](https://github.com/omnigent-ai/omnigent/pull/11389) for the deliveries; issue [#10745](https://github.com/omnigent-ai/omnigent/issues/10745)) |
| `claude-native-subagent-status` | Quiet sub-agents stay "running" until their turn actually ends. | proposed |
| `claude-native-coordinator-messages` | A parent agent's follow-ups appear in the sub-agent's chat. | proposed |
| `skip-gzip-binary-files` | Images and PDFs load in the file viewer again instead of failing with a 500. | PR open ([#10585](https://github.com/omnigent-ai/omnigent/pull/10585), carried copy) |
| `codex-native-mode-instructions` | Codex keeps its own Plan and Default mode instructions instead of having them replaced by the session's developer instructions. | proposed |
| `chat-item-labels` | Bracketed labels like `[Q2]` in chat become chips that preview the item they refer to; `~~[Q2]~~` closes it, and an Open items panel lists what is still open. Adds the labelling rules to agents' instructions. Needs `run-suggested-commands` and `codex-native-mode-instructions`. | proposed |
| `web-reconnect-shell-inputs` | A queued `!command` no longer stays stuck at the bottom of the chat after the connection drops. | PR open ([#11395](https://github.com/omnigent-ai/omnigent/pull/11395)) |
| `chat-item-comments` | Comment on labelled items and send the comments together as one structured message. Needs `chat-item-labels`. | proposed |
| `palette-new-chat-in-project` | The command palette can start a new chat in a chosen project. | PR open ([#11394](https://github.com/omnigent-ai/omnigent/pull/11394), draft; issue [#4409](https://github.com/omnigent-ai/omnigent/issues/4409)) |
| `new-chat-project-prompt` | When projects exist, starting a new session first asks which project, with a setting to turn it off. Needs `palette-new-chat-in-project`. | PR open ([#11397](https://github.com/omnigent-ai/omnigent/pull/11397), stacked on #11394; issue [#11083](https://github.com/omnigent-ai/omnigent/issues/11083)) |
| `session-labels-ui` | View and edit a session's labels in the web UI, delete labels through the API, and default labels per project. Needs `subscription-accounts`. | PR open ([#11398](https://github.com/omnigent-ai/omnigent/pull/11398) for the server, [#11399](https://github.com/omnigent-ai/omnigent/pull/11399) for the web UI (draft)) |
| `gateway-request-tags` | Requests to a Databricks Unity Gateway carry the session id and labels as request tags. Needs `chat-item-labels`. | proposed (issue drafted) |
| `chat-features` | Per-session toggles for chat features that need both an agent instruction and a renderer, starting with Run suggested commands. Needs several of the series above. | proposed |
| `pr-watch` | Watch a session's pull requests and wake the agent on failed checks, conflicts and reviews until they are green. Behind the default-off `pr_watch` feature flag. Needs `subscription-accounts`. | proposed |
| `claude-native-delegate-idle` | A Claude session stops showing Working, and takes follow-ups without Steer, once its turn ends while a background agent or teammate keeps running. Covers the default OSC status path and agent-team teammates, including lead turns a teammate's message starts. Needs `claude-native-teammates`. | PR open for the status-file part ([#10849](https://github.com/omnigent-ai/omnigent/pull/10849), carried copy); OSC and teammate parts proposed |
| `delete-stops-runner` | Deleting a session stops its host-launched runner once no remaining session uses it, instead of leaving the process running until its idle timeout. | PR open ([#11391](https://github.com/omnigent-ai/omnigent/pull/11391)) |
| `app-error-boundary` | A rendering error shows the error, its stack and a Reload button instead of a blank window. | proposed |
| `jump-to-latest` | A labelled Jump-to-latest pill, outside the scroll fade, that counts new replies landing below a reader who scrolled up. | proposed |
| `custom-docs-index` | `docs/custom/README.md`, the index of the series: what each changes, how to turn it on, and where its docs are. | custom only |

## Using the patches

### The whole series

Install a [release](https://github.com/Desidero/omnigent/releases)
(`release/README.md`), or fetch the fork's branch, which CI builds from this
repository:

```bash
git remote add patches-fork https://github.com/Desidero/omnigent.git
git fetch patches-fork custom
```

or apply the files yourself onto the base commit, in a clone of Omnigent that
has upstream as a remote (`scripts/build-custom.sh` does the same and gives
the same commits as the fork):

```bash
git -C ~/src/omnigent fetch https://github.com/omnigent-ai/omnigent.git
git -C ~/src/omnigent switch -c with-patches "$(cat patches/BASE)"
git -C ~/src/omnigent am -3 $(grep -v '^#' patches/series | sed "s|^|$PWD/patches/|")
```

### One series

Apply the patches of the series you want, in the order `patches/series` lists
them, after any series named on its `# needs:` lines. For example:

```bash
git am -3 /path/to/omnigent-patches/patches/toast-safe-area--*.patch
```

If your branch is ahead of `BASE` and a patch conflicts, `-3` lets git fall
back to a three-way merge; resolve it the usual way and `git am --continue`.
Turning on `git config rerere.enabled true` means you resolve each conflict
only once across rebases.

## Deploying your own

The releases are meant to be installed as they are: keep what is specific to
your machines (per-host service settings, secrets, runbooks) in a separate
repository of deployment config, and install a release tag with
`release/upgrade-host.sh --release <tag> --hosts-dir <your hosts/>` and the
image tag on the server. Production should run a tag that has already run
somewhere safe; `release/README.md` covers install, check and rollback.

If you need changes that will never go upstream, add them as their own series
in a fork of this repository rather than rebasing private commits onto the
build.

## Contributing

- Changes here are headed upstream, so they follow
  [Omnigent's contributing guide](https://github.com/omnigent-ai/omnigent/blob/main/CONTRIBUTING.md):
  sign off every commit (`git commit -s`, the
  [DCO](https://developercertificate.org/)), run `pre-commit`, and add tests.
- For a fix that is ready for upstream, open the PR against
  `omnigent-ai/omnigent` directly; it only needs to come here if it should be
  usable before it merges.
- To add or change a patch, follow [Developing a change](#developing-a-change)
  and send a pull request with the regenerated files.
- Screenshots and logs in `proposals/*/evidence/` must come from a throwaway
  server with dummy data. Never include credentials, real user data or
  private hostnames.

## License

Omnigent is licensed under the Apache License 2.0, and the patches here are
contributions to it under the same license. See [LICENSE](LICENSE).
