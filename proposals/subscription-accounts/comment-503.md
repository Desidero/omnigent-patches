@bbqiu @dhruv0811 @serena-ruan, as #583's reviewers: a design question before it merges. cc @Leemoonsoo for the `CLAUDE_CONFIG_DIR` handling in #9583.

I've been running per-session Claude accounts locally, with one difference from #583: each account is a `subscription` entry in `providers:` with its own `config_dir`, not a separate `claude_profiles:` block. `providers:` already allows any number of named entries and is what `executor.auth: {type: provider}` resolves against, so a second account doesn't need a second config concept:

```yaml
providers:
  claude-max1: {kind: subscription, cli: claude, config_dir: ~/.claude-max1, default: true}
  claude-max2: {kind: subscription, cli: claude, config_dir: ~/.claude-max2}
```

The host resolves the session's choice and exports `CLAUDE_CONFIG_DIR` to the runner, so claude-native works as well as claude-sdk. Omnigent's own reads of Claude's files follow it with #9617.

Two things I think should hold whichever shape wins:

1. An unknown or signed-out account fails the launch instead of falling back to `~/.claude`, since running on the wrong account is the concern this issue raises.
2. Since #9583, the agent's `env:` or an `env CLAUDE_CONFIG_DIR=… claude` startup command can change Claude's config dir after the host applies the session's account. I check the terminal's final launch environment (#9583's `_claude_terminal_launch_env`) and fail with a message saying what to change, instead of letting one setting quietly override the other.

Would you take a small first PR that adds `config_dir` to Claude subscription providers, plus "add another account" in `omnigent setup`? It changes no API or UI and doesn't block #583's session field. I'd follow up on per-session selection with whichever config shape you prefer, and I'm happy to work with @webdevtodayjason on it.
