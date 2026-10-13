# PFA — Dialyse

Django backend + MQTT ingestion pipeline + vision AI service for dialysis machine
monitoring, with a Flutter client in `mobile/`.

## Run with Docker

Requires Docker Desktop. From the project root:

```bash
docker compose up -d        # build + start the whole stack
docker compose ps           # check health
docker compose logs -f      # follow all services
docker compose down         # stop
```

| Service    | Port | What it is                                                   |
|------------|------|--------------------------------------------------------------|
| `web`      | 8000 | Django dashboard + REST API (`manage.py runserver`)          |
| `ai`       | 8001 | `qwen_api.py` — image → readings extraction (FastAPI)        |
| `mqtt`     | 1883 | Mosquitto broker (websockets on 9001)                        |
| `listener` | —    | `mqtt_listener.py` — MQTT → AI → validation → DB → alerts    |
| `css`      | —    | Tailwind watcher, rebuilds `static/css/index.css` on save    |

Landing page: <http://localhost:8000> · Sign in: <http://localhost:8000/connexion/> · Admin: <http://localhost:8000/admin/> ·
AI health: <http://localhost:8001/health>

Only the Django app is needed for most work:

```bash
docker compose up -d web
```

### How it is wired

- The project directory is bind-mounted into each Python service, so host edits
  reload immediately and `db.sqlite3` / `media/` stay on the host.
- `web` applies migrations on start (`RUN_MIGRATIONS=1`); `listener` waits for the
  schema before connecting.
- Configuration lives in `.env` (gitignored, created from `.env.example`). Email
  defaults to the console backend, so no SMTP credentials are needed locally.

### Styling

The interface is Tailwind v4, compiled from `static/css/src/app.css` into
`static/css/index.css`. **Never edit `index.css` by hand** — it is generated.

Design tokens (the clinical teal/slate palette, the status colours, light and
dark values) live in the `@theme` and `.dark` blocks of `app.css`. Templates use
semantic utilities — `bg-surface`, `text-body`, `text-critical` — so switching
theme repaints the whole app without a single `dark:` variant.

```bash
docker compose up -d css      # watcher: rebuilds on every template save
npm run css:build             # one-off minified build on the host
python3 -I scripts/audit_css.py   # fails if a template uses a class with no style
```

That last check exists for a reason: this project previously shipped a frozen
`index.css`, and a third of the classes in the templates silently did nothing.
Run it before committing a template change.

### Common commands

```bash
docker compose exec web python manage.py createsuperuser
docker compose exec web python manage.py migrate
docker compose exec web python manage.py shell

# publish a telemetry sample into the pipeline
docker compose exec mqtt mosquitto_pub -h localhost -t dialysis/machine/M001 \
  -m '{"machine_id":"M001","qb":320,"pa":-120,"pv":140,"ptm":180}'
```

### Optional host services

Two integrations are expected to run outside the stack and are reached via
`host.docker.internal`; both fail soft when absent.

- **Ollama** for real image reading (`ollama serve` + `ollama pull qwen2.5vl:3b`).
  Without it the AI service returns `_source: "ollama_fallback"` with null readings.
- **n8n** on port 5678 for critical-risk alert webhooks
  (`N8N_CRITICAL_RISK_WEBHOOK_URL`).

## Run without Docker

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-services.txt
python manage.py migrate && python manage.py runserver

npm install && npm run css:watch     # in a second terminal
```

See `start_system.py` for the four-terminal layout of the full pipeline.
