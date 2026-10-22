Title: [Feature] Tag Unity Gateway requests with the session's labels

### Problem or use case

Unity Gateway logs every inference request in its usage tracking table and inference tables, but nothing in a row says which Omnigent session sent it. To answer "what did this session (or this project, or this team's sessions) cost?" or "show me the requests behind this conversation", you have to match timestamps and users by hand.

The gateway already has a field for this. Requests can carry a `Databricks-Ai-Gateway-Request-Tags` header, a JSON object of string keys and values, and the gateway logs it in the `request_tags` column of both tables ([request tagging docs](https://docs.databricks.com/aws/en/ai-gateway/request-tagging)). Gateway service policies can also read the tags.

Omnigent already has the data. Every session has labels, and nothing sends the session id or labels to any provider today. #10410 added the `Databricks-Custom-Coding-Agent` / `Databricks-Custom-Client-Surfaces` attribution headers, but those are the same for every request a process sends.

### Proposed solution

When a harness targets a Unity Gateway URL (the same `is_databricks_ai_gateway_url` gating the attribution headers use), send `Databricks-Ai-Gateway-Request-Tags` built from the session:

- `omnigent_session_id`: the session id, so gateway rows join back to Omnigent sessions.
- The session's user labels, as-is. Internal labels (`omnigent.*`, `omni_project`, `cost_control.*`) are left out.
- The value is capped in size. When it is too large, labels are dropped in a fixed order and the session id is always kept.

Example for a session labelled `team=web`, `ticket=ENG-123`:

```
Databricks-Ai-Gateway-Request-Tags: {"omnigent_session_id":"conv_abc123","team":"web","ticket":"ENG-123"}
```

The canonical builder lives next to the attribution helpers in `omnigent/databricks_ai_gateway.py`. The harnesses only transport it:

- **Claude (native and SDK):** one more line in `ANTHROPIC_CUSTOM_HEADERS`, next to the coding-agent and attribution lines.
- **Codex (native and SDK):** the provider's `http_headers` / `env_http_headers`, taking the labels from the session the way #11000 turns a session label into a per-launch header.
- **Pi (SDK):** the header on gateway providers in its `models.json`.
- pi-native and opencode-native write their provider config through separate per-host paths, so they'd follow later.

Harness processes read the tags when they start, so a label edited mid-session shows up after the next terminal launch or harness respawn. That seems acceptable for attribution.

Third-party providers and gateways never get the header. It's on by default for Unity Gateway targets, with `OMNIGENT_GATEWAY_REQUEST_TAGS=0` to turn it off. Labels are user-authored and go only to the user's own workspace, but I'm happy to make it opt-in if maintainers prefer.

I can send a PR for this.

### Alternatives considered

- **A static tag per process** (what the closed #4326 servlet did with `{"source": "omnigent"}`): tells you the traffic came from Omnigent, but not which session.
- **Endpoint-level tags:** the same for every caller of an endpoint, so they can't tell sessions apart.
- **Joining on time and user downstream:** unreliable with several concurrent sessions, and needs database access from wherever the gateway tables are queried.
- **The OTel span attributes from #10794:** good for traces, but gateway usage and cost tables don't read traces.

Related: #10410 (static attribution headers), #11118 and #11099 (open, extend that attribution and touch the same helpers; the PR for this would rebase on them), #11000 (per-launch Codex header from a session label), #10794 (session attribution on spans).

### Harness

Claude, Codex, Pi

### Harness mode

SDK, Native

### Platform or device

Not platform-specific

### Expected reach

A substantial user segment (Databricks deployments that route inference through Unity Gateway)

### Authentication type

Databricks
