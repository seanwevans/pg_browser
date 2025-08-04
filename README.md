# pg_browser

*A tiny, database-native browser engine built entirely in PostgreSQL (schemas, tables, stored procedures, and extensions).*

`pg_browser` renders extremely simple apps and sites that only need a textbox, a button, and a display area—perfect for chatbots, forms, logs, dashboards, and terminal-style utilities. There is **no JavaScript engine, no CSS**, and no traditional DOM. Everything—fetching, parsing, layout, events, state, history, caching, and rendering—happens *inside* PostgreSQL.

> Status: **Pre-alpha** (design + initial schemas). We’ll iterate toward a usable MVP that renders a JSON UI (“PG-UI”) via an ASCII framebuffer.

---

## Why?

- **Deterministic & replayable**: Every event and network response is a row. Rewind sessions, diff frames, reproduce bugs.
- **DB = OS**: State, navigation, layout, and events are first-class data; transitions are stored procedures.
- **Minimal surface**: A handful of components (`text`, `pre`, `input`, `button`, `list`) and simple `vbox`/`hbox` layout.
- **Auditable**: No hidden runtime. Every render step is inspectable SQL.

---

## Core Concepts

- **PG-UI (JSON)**: A tiny, declarative UI format served by “sites” (or embedded locally). Example:
  ```json
  {
    "type": "vbox",
    "children": [
      {"type": "text", "value": "Chat"},
      {"type": "list", "id": "messages", "items": []},
      {
        "type": "hbox",
        "children": [
          {"type": "input", "id": "msg", "placeholder": "Type message…"},
          {
            "type": "button",
            "label": "Send",
            "on": {
              "click": {
                "post": "pgb://local/chat",
                "body": {"text": "@msg"},
                "append": {"target": "messages", "from": "response.text"}
              }
            }
          }
        ]
      }
    ]
  }
  ```
- **Event loop**: Keystrokes and clicks enqueue events; a dispatcher executes actions (HTTP POST or local stored proc), applies state deltas, re-layouts, and re-renders, then `NOTIFY`s the session channel.
- **Renderers**: Start with an **ASCII framebuffer** (rows of box-drawn text). Future: PNG bytea renderer.

---

## Features (MVP target)

- Session + history + state (jsonb)
- PG-UI ingestion (JSON only)
- Components: `text`, `pre`, `input`, `button`, `list`, `spacer`
- Layout: `vbox`/`hbox`, fixed font metrics, gaps/padding/alignment
- ASCII renderer (`render_ascii(session_id)`)
- Event queue + dispatcher (`input`, `click`)
- Networking: GET/POST for `application/json` and `application/pgui+json` (via extension)
- Cache (ETag/If-Modified-Since), per-session cookie jar (P1)
- `NOTIFY` on new frame

---

## Non-Goals (for now)

- Full HTML/CSS
- Arbitrary JavaScript execution
- Complex text shaping; variable fonts
- Mixed media (images/audio/video) beyond a minimal PNG renderer later

---

## Requirements

- PostgreSQL **16+**
- PL/pgSQL (built-in)
- Optional: an HTTP client extension (e.g., `pgsql-http`) **or** a custom C extension for HTTP(S)
- `uuid-ossp` (or `gen_random_uuid()` via `pgcrypto`) for IDs

---

## Install (planned)

When the schemas are published:

```bash
psql -d yourdb -f sql/00_install.sql
psql -d yourdb -f sql/10_pgb_net.sql
psql -d yourdb -f sql/20_pgb_dom.sql
psql -d yourdb -f sql/30_pgb_layout.sql
psql -d yourdb -f sql/40_pgb_view.sql
psql -d yourdb -f sql/50_pgb_events.sql
psql -d yourdb -f sql/60_pgb_session.sql
```

Optional:

```sql
-- If you choose to use pgsql-http:
CREATE EXTENSION IF NOT EXISTS http;
```

---

## Quickstart (design preview)

Below is how the P0 interface is intended to be used once implemented.

1) **Create a session and open a page**

```sql
-- A session creates state, history, and an event channel.
SELECT pgb_session.open('pgb://local/demo_chat') AS session_id;
-- → returns UUID
```

2) **Render the initial frame (ASCII)**

```sql
SELECT line_no, text
FROM pgb_view.render_ascii(:session_id);  -- rows of text representing the UI
```

3) **Type a message and click Send**

```sql
-- User types into input#msg
SELECT pgb_events.input(:session_id, 'msg'::uuid, 'hello');

-- User clicks the Send button
SELECT pgb_events.click(:session_id, 'send_button'::uuid);
```

4) **Receive updated frame**

```sql
-- Client listens for NOTIFY 'pgb_frame_ready,<session_id>'
-- Then pulls:
SELECT line_no, text FROM pgb_view.render_ascii(:session_id);
```

5) **Replay (debugging)**

```sql
-- Rewind to a prior timestamp and re-render:
SELECT pgb_session.replay(:session_id, '2025-08-04T15:30:00Z'::timestamptz);
SELECT * FROM pgb_view.render_ascii(:session_id);
```

> **Note:** The `pgb://local/demo_chat` origin maps to a stored procedure (no networking needed) so you can test end-to-end without HTTP.

---

## Security Model

- **Origin allowlist** per session
- **Strict MIME allowlist** (`application/pgui+json`, `application/json`, `text/plain`)
- **Sandboxed HTML-lite** (optional P1) — strictly parsed and converted to PG-UI
- **Size/time limits** on fetches; **cookie jar** is scoped per session
- **No script execution** of any kind

---

## Project Structure (planned)

```
sql/
  00_install.sql
  10_pgb_net.sql
  20_pgb_parse.sql
  20_pgb_dom.sql
  30_pgb_layout.sql
  40_pgb_view.sql
  50_pgb_events.sql
  60_pgb_session.sql
  90_devtools.sql
examples/
  demo_chat.pgui.json
docs/
  README.md
  ROADMAP.md
```

---

## Contributing

- File issues for design/API changes before implementation.
- Add **golden frame tests** for any renderer change (snapshot the ASCII output).
- All new functions require:
  - spec docstring,
  - example usage,
  - unit test (where applicable),
  - migration script.

---

## CI/CD

Automated GitHub Actions run PostgreSQL schema checks on every push and package
SQL files into a release archive when tags matching `v*` are created.

---

## License

TBD. (Suggest: permissive OSS like MIT/Apache-2.0.)

---

## Acknowledgments

- PostgreSQL community & extension authors.
