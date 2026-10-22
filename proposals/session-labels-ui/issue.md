Title: [Feature] View and edit session labels in the web UI, with default labels per project

### Problem or use case

Session labels are the one place to put your own metadata on a session (team, ticket, customer, purpose). Agent YAML seeds them, policies write them, and downstream tooling reads them. In the web UI they're invisible:

- The session info popover shows owner, session id, cost, MCP servers and policies, but not labels.
- You can't add a label to a running session without calling `PATCH /v1/sessions/{id}` by hand.
- You can't remove a label at all. The PATCH merges, and an empty value only deletes `omni_project` and the pin key, so any other label stays forever, either with its old value or stored as an empty string.
- Projects can't give their sessions a starting set of labels. Every session in a "customer-acme" project has to be labelled one by one, and sessions created through the API or an automation never get labelled.

Labels matter more as other features read them. For example, gateway request tags (proposed separately as the gateway-request-tags series) and trace attributes are only as good as the labels on the session.

### Proposed solution

1. **A Labels section in the session info popover.** It lists the session's user labels as `key: value` and lets anyone with edit permission add, change and remove them. Internal labels (`omnigent.*`, `omni_project`, `cost_control.*`) stay hidden. Viewers without edit permission see the list read-only. Keys and values are limited to the database limits (128 and 256 characters), with an inline message when one is too long.
2. **Deleting a label through the API.** In `PATCH /v1/sessions/{id}`, `"labels": {"ticket": null}` deletes `ticket`. Reserved keys stay protected exactly as they are today; deleting one is rejected the same way setting it is. The existing empty-string behaviour for `omni_project` and the pin is unchanged.
3. **Default labels in project settings.** A "Default labels" editor in the project settings dialog, stored as `labels` in the project config. The server merges them into the labels of any session created in that project, with the request's own labels winning on conflict, in `resolve_project_session_create` next to the agent, workspace and git defaults it already applies. Because this happens on the server, API, automation and import creates get them too. They apply at creation only; moving an existing session into the project doesn't relabel it.

Empty values are allowed, so a key on its own works as a simple tag.

I can send a PR for this.

### Alternatives considered

- **Multi-valued tags (#2117):** that design scoped a `conversation_tags` table for bulk sharing and search and was closed in July as internal for now. This proposal doesn't add a data model. It exposes the single-valued labels that already exist and leaves room for tags later. If tags are still planned, I'd like to know whether a labels editor would conflict with that direction.
- **Setting labels from agent YAML** (`guardrails.labels`): only fixed values per agent, not per session or per project, and not editable afterwards.
- **Client-side project defaults** (the way the composer pre-fills agent and model): misses API, CLI and automation creates.

Related: #2117 / #2118 (session tags design, closed), #8689 (Python client has no label update method, and doesn't say whether a labels patch merges or replaces).

### Harness

Not applicable

### Platform or device

Not platform-specific

### Expected reach

Some users

### Authentication type

Not authentication-related
