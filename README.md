# omnigent-patches

Candidate contributions to [Omnigent](https://github.com/omnigent-ai/omnigent),
kept as a patch series until they land upstream.

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
- `scripts/` regenerates and checks the series.

The same commits are available as a branch: `custom` on
[Desidero/omnigent](https://github.com/Desidero/omnigent/tree/custom) is
upstream plus this whole series, rebased as upstream moves.

## Patch index

Status is one of: **proposed** (not yet filed upstream; see `proposals/`),
**issue open** (an upstream issue tracks it), or **PR open** (an upstream pull
request carries it, and this repository holds a copy until it merges).

| Series | What it does | Status |
|---|---|---|
| `claude-config-dir` | claude-native and claude-sdk follow `CLAUDE_CONFIG_DIR` instead of assuming `~/.claude`. | PR open ([#9617](https://github.com/omnigent-ai/omnigent/pull/9617), carried copy) |
| `subscription-accounts` | Several Claude or Codex subscription logins per host: pick the account for a new session, switch a running session's account from the harness menu, accounts that share sessions through account tokens, and agents can start a child session on another account. Docs in `docs/providers.md`. Needs `claude-config-dir`. | issue open ([#503](https://github.com/omnigent-ai/omnigent/issues/503)) |
| `toast-safe-area` | Toasts stay below the iOS status bar and Dynamic Island. | proposed |
| `session-history-paging` | Agents can page through a session's history and list recently updated sessions. | proposed |
| `terminal-touch` | The terminal on phones and tablets: a Termux-style extra-keys row, long-press select, copy and paste, and native iOS clipboard reads for Paste. | PR open for the extra-keys row ([#6136](https://github.com/omnigent-ai/omnigent/pull/6136), carried copy with two iOS fixes); the rest proposed |
| `telemetry-attribution` | Exported spans carry the acting user (opt-in), runner and host. | issue open ([#10794](https://github.com/omnigent-ai/omnigent/issues/10794)) |
| `sidebar-attention-filter` | Sidebar filters for sessions that need you or changed recently. | proposed |
| `claude-sdk-web-tools` | claude-sdk agents can opt into Claude Code's WebSearch and WebFetch. | proposed |
| `run-suggested-commands` | A Run button on shell commands an agent suggests in chat. | proposed |
| `claude-native-teammates` | Claude Code agent-team teammates show up as child sessions, and their deliveries no longer appear as raw `<teammate-message>` bubbles. | issue open ([#10745](https://github.com/omnigent-ai/omnigent/issues/10745)) |
| `claude-native-subagent-status` | Quiet sub-agents stay "running" until their turn actually ends. | proposed |
| `claude-native-coordinator-messages` | A parent agent's follow-ups appear in the sub-agent's chat. | proposed |
| `skip-gzip-binary-files` | Images and PDFs load in the file viewer again instead of failing with a 500. | PR open ([#10585](https://github.com/omnigent-ai/omnigent/pull/10585), carried copy) |
| `codex-native-mode-instructions` | Codex keeps its own Plan and Default mode instructions instead of having them replaced by the session's developer instructions. | proposed |
| `chat-item-labels` | Bracketed labels like `[Q2]` in chat become chips that preview the item they refer to; `~~[Q2]~~` closes it, and an Open items panel lists what is still open. Adds the labelling rules to agents' instructions. Needs `run-suggested-commands` and `codex-native-mode-instructions`. | proposed |
| `web-reconnect-shell-inputs` | A queued `!command` no longer stays stuck at the bottom of the chat after the connection drops. | proposed |
| `chat-item-comments` | Comment on labelled items and send the comments together as one structured message. Needs `chat-item-labels`. | proposed |
| `palette-new-chat-in-project` | The command palette can start a new chat in a chosen project. | issue open ([#4409](https://github.com/omnigent-ai/omnigent/issues/4409)) |
| `new-chat-project-prompt` | When projects exist, starting a new session first asks which project, with a setting to turn it off. Needs `palette-new-chat-in-project`. | issue open ([#11083](https://github.com/omnigent-ai/omnigent/issues/11083)) |
| `session-labels-ui` | View and edit a session's labels in the web UI, delete labels through the API, and default labels per project. Needs `subscription-accounts`. | proposed (issue drafted) |
| `gateway-request-tags` | Requests to a Databricks Unity Gateway carry the session id and labels as request tags. Needs `chat-item-labels`. | proposed (issue drafted) |
| `chat-features` | Per-session toggles for chat features that need both an agent instruction and a renderer, starting with Run suggested commands. Needs several of the series above. | proposed |
| `pr-watch` | Watch a session's pull requests and wake the agent on failed checks, conflicts and reviews until they are green. Behind the default-off `pr_watch` feature flag. Needs `subscription-accounts`. | proposed |

## Using the patches

### The whole series

Apply every patch onto the base commit with `git am -3`, in a clone of
Omnigent that has upstream as a remote:

```bash
git -C ~/src/omnigent fetch https://github.com/omnigent-ai/omnigent.git
git -C ~/src/omnigent switch -c with-patches "$(cat patches/BASE)"
git -C ~/src/omnigent am -3 $(grep -v '^#' patches/series | sed "s|^|$PWD/patches/|")
```

Or skip the files and use the fork's branch, which has the same tree:

```bash
git remote add patches-fork https://github.com/Desidero/omnigent.git
git fetch patches-fork custom
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

## Keeping a private downstream

If you run Omnigent with changes of your own that will never go upstream
(deployment config, internal integrations), a pattern that stays easy to
maintain:

1. Create a private repository whose `main` is this series' `custom` branch
   plus your private commits on top. Keep each private change a small,
   self-contained commit whose message says why it exists.
2. Deploy from release tags on that `main` (for example `release/<date>`), not
   from the moving branch, so you always know what is running.
3. After the public series is refreshed, rebase your private commits onto the
   new `custom` (never merge it in), run your tests, and cut a new tag once it
   has run somewhere safe.
4. When one of your private changes turns out to be generally useful, propose
   it upstream and, while it waits, here.

## Maintaining the series

The source of truth is the `custom` branch: upstream plus one commit per
patch, rebased (not merged) onto upstream.

1. Edit on `custom`: rebase it onto the latest upstream, add or amend commits,
   and drop any patch that has landed upstream. Keep fixups squashed into the
   patch they fix.
2. Export: `scripts/export.sh --repo <omnigent-clone> custom upstream/main`
   rewrites `patches/BASE`, `patches/series` and the patch files. Series are
   matched by each commit's subject; a new commit joins the previous commit's
   series with a warning, so move it in `patches/series` if it belongs
   elsewhere and run the export again. `# needs:` lines and other comments in
   a series are kept.
3. Check: `scripts/check.sh --repo <omnigent-clone> --custom custom` applies
   the series onto `BASE` in a temporary worktree with `git am -3`, runs a
   quick sanity check (no conflict markers, changed Python and JSON files
   parse), and verifies the result has exactly the tree of `custom`.
   `--report` also posts the result as a commit status (`patches/apply`) on
   the custom commit with `gh api`.
4. Commit the regenerated files together with any proposal updates.

`.github/workflows/check.yml` runs the same check on every push and pull
request: it shallow-fetches upstream at `BASE` and the fork's `custom` branch
and fails if the series no longer applies or no longer matches. The
repositories default to `omnigent-ai/omnigent` and `Desidero/omnigent`; set
the repository variables `UPSTREAM_REPO`, `FORK_REPO` and `CUSTOM_BRANCH` to
point it elsewhere.

## Contributing

- Changes here are headed upstream, so they follow
  [Omnigent's contributing guide](https://github.com/omnigent-ai/omnigent/blob/main/CONTRIBUTING.md):
  sign off every commit (`git commit -s`, the
  [DCO](https://developercertificate.org/)), run `pre-commit`, and add tests.
- For a fix that is ready for upstream, open the PR against
  `omnigent-ai/omnigent` directly; it only needs to come here if it should be
  usable before it merges.
- To add or change a patch, make the change as commits on a branch cut from
  `custom`, export it (`scripts/export.sh`, then `scripts/check.sh` against
  that branch), and send a pull request with the regenerated files, plus
  `proposals/<series>/PR.md` for a new series. Link the branch so the
  maintainer can update `custom` to match.
- Screenshots and logs in `proposals/*/evidence/` must come from a throwaway
  server with dummy data. Never include credentials, real user data or
  private hostnames.

## License

Omnigent is licensed under the Apache License 2.0, and the patches here are
contributions to it under the same license. See [LICENSE](LICENSE).
