# PFA — Dialyse

Dialysis monitoring project with a Next.js web client, Django API, Flutter
mobile app, and separate AI and MQTT processing services.

## Repository layout

```text
app/
  web/       Next.js web interface
  mobile/    Flutter app
  api/
    django/  Django project, domain apps, API, and admin
    ai/      FastAPI image analysis service
    mqtt/    MQTT listener and edge client
```

Docker Compose, broker configuration, scripts, local environment files, and
runtime data remain at the repository root.

## Run with Docker

Requires Docker Desktop. From the repository root:

```bash
docker compose up -d        # web, API, broker, AI service, MQTT listener
docker compose ps           # check health
docker compose logs -f      # follow services
docker compose down         # stop
```

| Service | Port | Purpose |
|---|---:|---|
| `web` | 3000 | Next.js interface; proxies API and legacy routes to Django |
| `api` | 8000 | Django API, admin, and pages still being migrated |
| `ai` | 8001 | FastAPI image analysis service |
| `mqtt` | 1883, 9001 | Mosquitto broker and WebSocket listener |
| `listener` | — | MQTT → AI → validation → database → alerts |

Open <http://localhost:3000> for the web app, <http://localhost:8000/admin/>
for Django admin, or <http://localhost:8001/health> for AI health.
Flutter continues to use the Django API on port 8000.

The Next.js app proxies `/api`, `/static`, and `/media` to Django. Routes that
have not yet moved to Next.js fall back to Django during the incremental UI
migration. Django session authentication and API responses remain authoritative.

### Configuration

Copy `.env.example` to `.env` and set credentials as needed. Docker Compose
mounts the repository into the Python services, keeping `db.sqlite3`, `media/`,
and the edge offline buffer on the host. Django applies migrations at startup.

The current Tailwind watcher builds styles for Django pages that have not moved
to Next.js yet. Next.js serves the shared files under `/static/` from its public
directory; Django also sees them through `STATICFILES_DIRS`:

```bash
docker compose up -d css
npm run css:build
python3 -I scripts/audit_css.py
```

### Common commands

```bash
docker compose exec api python manage.py createsuperuser
docker compose exec api python manage.py migrate
docker compose exec api python manage.py shell
```

### Optional host services

Two integrations run outside the stack and fail soft when absent:

- **Ollama** for image reading (`ollama serve` + `ollama pull qwen2.5vl:3b`).
- **n8n** on port 5678 for critical-risk alert webhooks.

## Run without Docker

Start the Django API and companion services from the repository root:

```bash
pip install -r app/api/requirements.txt -r app/api/requirements-services.txt
cd app/api/django && python manage.py migrate && python manage.py runserver
```

In another terminal, start Next.js:

```bash
cd app/web
npm ci
npm run dev
```

The API defaults to `http://127.0.0.1:8000`. Set `DJANGO_API_ORIGIN` if Django
runs elsewhere. Flutter is under `app/mobile/`; see its README for Flutter
commands.
