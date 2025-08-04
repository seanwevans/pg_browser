# pg_browser Roadmap

This roadmap tracks the path from a design prototype to a minimal, usable database-native browser engine.

**Legend**
- **Milestone** → a cohesive deliverable
- **Module** → schema(s) and stored procedures
- **DoD** → definition of done (acceptance tests)
- **↳ Stretch** → optional scope if time permits

---

## Milestone P0 — “Hello Browser” (ASCII, JSON-only)

**Goal:** Load a PG-UI JSON page, render to ASCII, accept input and clicks, dispatch actions (local SQL), update state, and re-render.

### Scope

**Modules**
- `pgb_session`
  - `session(id, created_at, current_url, state jsonb, focus uuid)`
  - `history(session_id, n, url, ts)`
  - Functions: `open(url) → uuid`, `reload(uuid)`, `replay(uuid, ts)`
- `pgb_dom`
  - `node(id, session_id, parent_id, type, props jsonb, data jsonb, order int)`
  - `bindings(node_id, expr text)` (e.g., `"@msg"`)
  - Fn: `ingest_json(session_id, jsonb)` → populates `node`
- `pgb_layout`
  - `render_ops(session_id, seq, op text, args jsonb)`
  - Fn: `layout(session_id)` (vbox/hbox, fixed metrics)
- `pgb_view`
  - Fn: `render_ascii(session_id) RETURNS TABLE(line_no int, text text)`
- `pgb_events`
  - `event(id bigserial, session_id, target uuid, type text, payload jsonb, ts timestamptz)`
  - Fn: `input(session_id, target uuid, text)`, `click(session_id, target uuid)`
  - Dispatcher: applies actions; marks session dirty; `NOTIFY pgb_frame_ready,<session>`
- `pgb_net` (local only)
  - Scheme: `pgb://local/<app>` → routed to a stored proc
  - Fn: `call_local(url text, body jsonb) → jsonb`

**Components**
- `text`, `pre`, `input`, `button`, `list`, `spacer`
- Layout containers: `vbox`, `hbox`
- Attrs: `grow`, `align:{start,center,end,stretch}`, `gap`, `padding`

**Actions**
- `post` (local only in P0): maps to stored proc by URL; returns JSON
- `append` / `replace` updates `node.data`
- Basic binding resolution (e.g., `{"text":"@msg"}`)

**DevTools**
- Views: `pgb_dev.dom(session_id)`, `pgb_dev.state(session_id)`, `pgb_dev.events(session_id)`

### DoD

- `SELECT pgb_session.open('pgb://local/demo_chat')` returns a session id.
- `render_ascii(session)` returns non-empty frame with `input#msg` and **Send** button.
- `input()` + `click()` updates the `messages` list and re-renders.
- `NOTIFY` is emitted on re-render.
- `replay()` restores an earlier state and re-renders deterministically.
- 10+ **golden frame tests** pass (snapshot ASCII output).

**↳ Stretch**
- Focus model (tab/enter)
- Minimal validation errors rendered under inputs

**Estimated effort:** ~2–5 days.

---

## Milestone P1 — Networking, Cache, Cookies, HTML-lite Import

**Goal:** Fetch PG-UI from remote hosts with a strict content policy. Add ETag/If-Modified-Since cache and per-session cookies. Optional HTML-lite to PG-UI importer.

### Scope

**Networking**
- `pgb_net.cache(url pk, etag, last_modified, body bytea, mime, ts)`
- `pgb_net.cookies(session_id, domain, name, value, path, expires, secure, http_only)`
- Functions: `get(url)`, `post(url, jsonb)`; 30s timeout; size limit; redirect policy
- Origin allowlist per session
- MIME allowlist: `application/pgui+json`, `application/json`, `text/plain`

**Importer**
- `pgb_parse.import_html(html text) → jsonb` (tight whitelist of tags/attrs)

**DoD**
- `open('https://example.test/hello.pgui')` loads & renders from cache on 2nd load.
- Cookies are set and re-sent to same origin.
- HTML-lite sample converts to PG-UI and renders.

**↳ Stretch**
- Simple form encoding in `post()`

**Estimated effort:** ~1–2 weeks.

---

## Milestone P2 — PNG Renderer & Visual Polish

**Goal:** Bytea PNG renderer for higher-fidelity clients; font atlas table; borders and box drawing.

### Scope
- `pgb_view.render_png(session_id) RETURNS bytea`
- `pgb_view.fonts(name, w, h, glyphs bytea)` (fixed metrics)
- Render ops map to pixels; borders/padding/gaps are visible

**DoD**
- PNG output resembles ASCII output for golden frames.
- ~5 visual regression tests compare hashes/sizes.

**Estimated effort:** ~1 week.

---

## Milestone P3 — Live Feeds (WebSocket-like) & Lists

**Goal:** Basic streaming updates to lists via a background job or WS-ish extension.

### Scope
- `pgb_net.subscribe(url)`, `pgb_net.unsubscribe()`
- Dispatcher can `append` to `list` as messages arrive
- Backpressure via pagination (`items[offset,limit]`)

**DoD**
- Demo “live log tail” updates without user interaction.

**Estimated effort:** ~1–2 weeks.

---

## Milestone P4 — Packaging, Permissions, Quotas

**Goal:** Treat apps as importable/exportable bundles and add resource limits.

### Scope
- `pgb_pkg.apps`, `pgb_pkg.pages`, `pgb_pkg.actions`
- `pgb_pkg.export(app_id) → jsonb`, `pgb_pkg.import(jsonb)`
- Per-app quotas (rows, bytes, requests/min)
- Roles & grants: read/write/execute app actions

**DoD**
- Export/import a demo app between databases.
- Quota denial is observable and logged.

**Estimated effort:** ~1–2 weeks.

---

## Milestone P5 — DevTools & Golden Testing

**Goal:** First-class developer experience.

### Scope
- `pgb_dev.snapshot(session,label)`, `pgb_dev.diff(a,b)`
- Frame diffing (render_ops delta)
- Trace view: per-event execution time, queries, rows touched

**DoD**
- CI runs golden frame + performance thresholds.
- Time-travel debugging demonstrated in docs.

**Estimated effort:** ~1 week.

---

## Risks & Mitigations

- **HTTP inside PG**: Extension availability varies → provide local `pgb://` scheme and pluggable net layer.
- **Rendering speed**: Keep integer-only layout; precompute render ops; cache frames.
- **Concurrency**: Use advisory locks per session; idempotent event processing.
- **Security**: Strict MIME/origin allowlists; size/time caps; no script execution.

---

## Open Questions

1. Use `pgsql-http` vs. write a small custom HTTP C extension?
2. Include HTML-lite importer in P1 or defer to P2+?
3. Default security stance: closed (allowlist) or open with warnings?
4. How much PNG fidelity do we want (fonts, RTL, bidi) vs. staying mono-spaced?

---

## Definition of Done (Project)

- P0–P2 features implemented with docs and examples.
- Golden tests stable across PG 16/17.
- At least two example apps:
  1. **Chatbot** (local action)
  2. **Log viewer** (live feed substitute)
- Benchmarks published: events/sec, render latency, DB footprint.

---

## High-Level Timeline (tentative)

- **Week 1**: P0
- **Weeks 2–3**: P1
- **Week 4**: P2
- **Week 5**: P3
- **Week 6**: P4
- **Week 7**: P5 & polish

(Adjust based on contributors and extension choices.)
