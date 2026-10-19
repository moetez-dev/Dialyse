# Dialyse local development on Windows

This runbook is for the existing `feature/ui-overhaul` branch and the Docker
Compose stack at the repository root. Use PowerShell for every host command.
Commands below do not reset the database, remove volumes, merge branches, or
rewrite Git history.

## What was verified in this checkout

- The repository remote is `origin` at `https://github.com/moetez-dev/Dialyse.git`.
- The current branch is `feature/ui-overhaul`, tracking
  `origin/feature/ui-overhaul`.
- The inspected `HEAD` was `50d53ef` (`Ajouter les formulaires de création
  des ressources`); the local branch was tracking the same-named remote branch.
- The Compose services are `web`, `api`, `ai`, `css`, `mqtt`, and `listener`.
- The `web` service runs `next dev`; its source is bind-mounted and its
  `node_modules` directory is a named volume. It runs `npm ci` when its
  container starts.
- `api`, `ai`, and `listener` use the shared image built from
  `app/api/Dockerfile`. Django runs migrations automatically when the API
  container starts.
- Django uses SQLite at the repository-root `db.sqlite3`. Compose bind-mounts
  the repository into the Python containers; SQLite is **not** stored in a
  Docker named volume. This repository tracks `db.sqlite3`; the inspected
  working tree had a local modification to it.
- Only `api` and `ai` define Docker health checks. `web`, `css`, `mqtt`, and
  `listener` do not have health checks.
- At inspection time, all six Compose containers were running; `api` and `ai`
  reported healthy. Container state can change after this runbook is written.

## 1. First-time startup

### A. Start from a fresh clone

Make sure Docker Desktop is installed and running before starting the stack.
Clone the intended branch rather than the default branch:

```powershell
Set-Location "$HOME\Downloads"
git clone --branch feature/ui-overhaul --single-branch https://github.com/moetez-dev/Dialyse.git Dialyse
Set-Location "$HOME\Downloads\Dialyse"
```

Confirm that this is the expected repository, branch, and working tree:

```powershell
git rev-parse --show-toplevel
git remote -v
git branch --show-current
git status --short
```

The branch command should print `feature/ui-overhaul`; the remote should be
`origin` and point to `moetez-dev/Dialyse`. If `git status --short` lists files,
inspect and preserve them before switching branches or staging anything. Do
not run a branch switch on the assumption that uncommitted work is disposable.

### B. Prepare `.env` without replacing existing configuration

Compose requires a root-level `.env` because `api`, `ai`, and `listener` use it
as an `env_file`. Create it from the example **only if it does not already
exist**:

```powershell
if (-not (Test-Path -LiteralPath ".env")) {
    Copy-Item -LiteralPath ".env.example" -Destination ".env"
    Write-Host "Created .env from .env.example. Edit it before starting Compose."
} else {
    Write-Host ".env already exists; it was not overwritten."
}
notepad .env
```

Set a private, random `DJANGO_SECRET_KEY` and a non-placeholder `EDGE_API_KEY`.
The example file contains placeholders; in particular, the example edge key
is explicitly rejected by the application. Supply email credentials only if
you need email features. The names shown by the example include
`DJANGO_SECRET_KEY`, `DJANGO_DEBUG`, `EMAIL_HOST_USER`,
`EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL`, and `EDGE_API_KEY`. Compose also
sets service-specific values such as the Django allowed hosts, MQTT broker,
AI service URL, and the AI container's Ollama URL.

Do not paste `.env` contents into chat, tickets, screenshots, or Git. Confirm
only that the file exists and that it is ignored by Git; these commands do not
display secret values:

```powershell
Test-Path -LiteralPath ".env"
git check-ignore .env
Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#=\s][^=]*)=') { $Matches[1] }
}
```

The last command prints variable **names only**.

### C. Check Docker and start the complete stack

Open Docker Desktop and wait until its engine is running. Then check the
installed Docker CLI, Compose plugin, and Compose configuration:

```powershell
docker version
docker compose version
docker compose config --quiet
docker compose config --services
```

`docker compose config --quiet` checks configuration without dumping the
resolved environment to the terminal. The services command should list
`web`, `api`, `ai`, `css`, `mqtt`, and `listener`.

From the repository root, build the shared Python image and start all services:

```powershell
docker compose up -d --build --wait
docker compose ps --all
```

The `--wait` option waits for services to be running or healthy. The Django API
and FastAPI AI service have health checks; the other services report running
state only. Compose waits for `api` to be healthy before starting `web` and
`listener`; it waits for the MQTT container to start before starting
`listener`. If the command times out or reports an unhealthy service, inspect
that service's logs before trying a rebuild.

The `api` entrypoint applies Django migrations automatically on startup
(`RUN_MIGRATIONS=1`). It is not necessary to run `migrate` on every ordinary
start.

### D. Open the local services

- Next.js application: <http://localhost:3000/>
- Surveillance page: <http://localhost:3000/monitoring/surveillance/>
- Django admin: <http://localhost:8000/admin/>
- Authenticated live API example:
  <http://localhost:8000/api/monitoring/live/>
- FastAPI health check: <http://localhost:8001/health>
- MQTT broker: `localhost:1883` (MQTT); `localhost:9001` (WebSocket)

There is no API index at `/api/`; open a real route such as the authenticated
live API example above. A `401` from that route while not signed in is expected.
The AI health endpoint indicates whether the FastAPI process is healthy. It
does not guarantee that an optional host-side Ollama model is available.
The broker has no browser dashboard configured.

## 2. Short daily workflow

Open PowerShell and run:

```powershell
Set-Location "C:\Users\moetez\Downloads\Dialyse-ui-overhaul"
git branch --show-current
git status --short
docker compose up -d --wait
docker compose ps --all
```

The working directory above is the checkout inspected for this runbook. If
your clone is in a different location, use that repository root instead. Check
that the branch output is `feature/ui-overhaul` before editing. Review every
line from `git status --short`: this checkout already has unrelated modified
and untracked files, including a modified `db.sqlite3`. Do not stage all files
or discard them as a routine cleanup.

Open <http://localhost:3000/monitoring/surveillance/> in a browser and sign in
with an account already configured for the application.

When finished for the day:

```powershell
docker compose stop
```

Closing the PowerShell window does **not** stop detached containers started
with `-d`. `docker compose stop` stops containers but retains them, named
volumes, and the host database file. Docker Desktop may leave containers
stopped after Windows restarts; containers in this Compose file do not declare
an automatic restart policy. On the next day, `docker compose up -d --wait`
starts or reconciles the full stack again.

## 3. Which Compose command should I use?

| Command | Use it when | Effect |
|---|---|---|
| `docker compose start` | All required containers already exist and you only stopped them; the Compose configuration has not changed. | Starts existing containers. Does not create missing containers, rebuild images, or reconcile configuration changes. |
| `docker compose up -d --wait` | Normal daily startup, or when Compose should create/reconcile containers using the current configuration. | Starts the stack without explicitly rebuilding images. Source bind mounts remain live. |
| `docker compose up -d --build --wait` | First setup, or after a Dockerfile or image-built dependency change. | Builds services that have a `build:` definition, then starts the stack. In this project that is the shared API/AI/listener image; the `web` service uses `node:24-alpine` directly and has no Compose `build:` section. |
| `docker compose restart web` | The existing web container needs a simple restart. | Restarts only the existing web container. Its start command runs `npm ci` and then `next dev`; it does not rebuild an image or apply changed Compose configuration. |
| `docker compose up -d --force-recreate web` | Web service configuration changed and must be applied to a newly created container. | Recreates the web container without building an image. |
| `docker compose up -d --build --wait api ai listener` | Django/Python Dockerfile or Python requirements changed. | Rebuilds the shared Python image and updates the named Python services. The `css` image-build stage is part of the shared Dockerfile. |

The web source is bind-mounted from `app/web`, so normal source edits are
served by Next.js hot reload. The named `web-node-modules` volume holds web
dependencies; the configured startup command runs `npm ci`. A web dependency
change does not by itself justify rebuilding the Python image.

The separate `css` watcher uses the root `package.json` and root lockfile for
legacy Django templates. If those dependencies change, restart `css` so its
startup command runs `npm install` again:

```powershell
docker compose restart css
```

## 4. Branch safety: stay on `feature/ui-overhaul`

### Verify before working

```powershell
git rev-parse --show-toplevel
git branch --show-current
git branch -vv
git status --short
```

Do not start feature work unless `git branch --show-current` says
`feature/ui-overhaul`. At inspection, this branch tracked
`origin/feature/ui-overhaul`; the current checkout's branch was **not** `main`.

### If you need to switch to the feature branch

First inspect and preserve local work. Modified, deleted, and untracked files
are all work until you have deliberately dealt with them. Prefer making a
clearly scoped commit or a separate backup. A stash can preserve ordinary
changes, including untracked files when `-u` is used, but inspect its contents
and account for local databases or other large/private data first:

```powershell
git status --short
git diff --stat
git stash push -u -m "before switching to feature/ui-overhaul"
git stash list
```

Only after verifying the work is preserved, switch by the confirmed branch
name:

```powershell
git switch feature/ui-overhaul
git branch --show-current
```

Do not use `git switch -f`, `git checkout --`, `git reset --hard`, or
`git clean -fd` to get past a dirty tree.

### Fetch and compare without merging

Fetch updates without integrating them into the working branch:

```powershell
git fetch origin
git status -sb
git log --oneline --left-right feature/ui-overhaul...origin/feature/ui-overhaul
git diff --stat feature/ui-overhaul origin/feature/ui-overhaul
```

In the log, `<` marks commits only on the local side and `>` marks commits
only on the remote side. Fetching does not merge or rebase. If both sides have
unique commits, they have diverged: stop, keep a backup, inspect the commit
lists and diffs, and agree on an integration plan. Do not reset, rebase,
merge, or rewrite history as an automatic response.

### Commit and push only your intended changes

Review the branch, status, and exact staged patch. Stage explicit paths; do
not use `git add .` or `git add -A` in this checkout because it already has
unrelated changes and a modified database:

```powershell
git branch --show-current
git status --short
git diff --check
git add -- path\to\your\intended-file
git diff --cached --stat
git diff --cached
git commit -m "Describe your change"
git status -sb
```

The inspected branch already tracks `origin/feature/ui-overhaul`. Push by
naming both the remote and branch explicitly:

```powershell
git push origin feature/ui-overhaul
```

Before pushing, confirm the branch and commit. Never substitute `main`, and
do not force-push as a normal workflow. If a push is rejected because the
remote has new commits, fetch and compare first; do not force the update.

## 5. Environment, database, and volume safety

- `.env.example` documents configuration names and contains placeholders.
  `.env` contains machine-specific configuration and credentials; it is
  ignored by Git and must not be committed or shared.
- Compose loads `.env` into `api`, `ai`, and `listener`. The required env file
  must exist before Compose starts, even if optional email settings are blank.
- Django settings select SQLite at the repository root. The repository is
  bind-mounted into the Python containers, so `db.sqlite3` is a **host file**,
  not a named Docker volume. It remains when containers stop, restart, or are
  removed. This checkout tracks that file and currently has local database
  changes; never stage it as an incidental part of another change.
- Docker named volumes include `web-node-modules`,
  `legacy-css-node-modules`, and `mosquitto-data`. They survive container
  stop/restart and ordinary `docker compose down`.
- `docker compose stop`, `docker compose start`, `docker compose up -d`, and
  `docker compose restart web` do not intentionally remove volumes or the
  host database.
- **Never run `docker compose down -v` as routine cleanup.** The `-v` option
  removes Compose named volumes, including the MQTT data volume.
- Do not delete `db.sqlite3`, remove Docker volumes, or reinitialize/reset the
  database to fix a frontend problem. Those actions can destroy local data and
  are not routine troubleshooting.

## 6. Troubleshooting

| Symptom | Diagnostic command | What the result means | Safe next step |
|---|---|---|---|
| Docker Desktop is not running | `docker version` | If the client is shown but the server cannot be reached, the Docker engine is not ready. | Open Docker Desktop and wait until it reports that the engine is running; retry the command. |
| Port 3000, 8000, or 8001 is unavailable | `Get-NetTCPConnection -State Listen -LocalPort 3000,8000,8001 -ErrorAction SilentlyContinue` | A listed listener owns that host port; Compose may be unable to bind it. The output includes its PID. | Inspect the PID with `Get-Process -Id <PID>`. Close only a process you recognize and own, or coordinate a port change; do not stop unknown processes. |
| A container exits or becomes unhealthy | `docker compose ps --all` and `docker compose logs --tail 100 api` (replace `api` with the affected service) | `Exited`, `unhealthy`, or repeated startup errors indicate the container did not become ready. Only `api` and `ai` have configured health checks. | Read the full relevant logs with `docker compose logs --tail 200 <service>`. Fix the reported configuration or dependency first; rebuild only for image/Dockerfile/dependency changes. |
| Frontend shows stale code after a source edit | `docker compose logs --tail 100 web` and `docker compose ps web` | The web command is `next dev` and the source is host bind-mounted; hot reload should normally pick up edits. | Confirm the edit was saved in this checkout, refresh the browser, then try `docker compose restart web`. Do not reset the database or rebuild the Python image. |
| Django reports a migration error | `docker compose logs --tail 200 api` | The API entrypoint runs `python manage.py migrate --noinput`; the log identifies the failed migration or database lock. | Preserve `db.sqlite3`, inspect the specific migration error, and coordinate schema changes. Do not delete/recreate the database as a shortcut. |
| Login/API returns 401 or 403 | `docker compose logs --tail 100 api` | `401` commonly means the request lacks a valid session; `403` commonly means the account lacks the required role/permission. The live API is authenticated. | Sign in with a configured account and check its role and session. Do not weaken authentication or paste credentials into logs/chat. |
| An API route returns 404 | `docker compose logs --tail 100 web api` | The URL may be wrong, or the route may be served by Django rather than Next.js. Next rewrites API and legacy paths to Django. | Use the actual route and trailing-slash convention from the project; `/api/` itself is not an API index and returns 404. Check a specific route such as `/api/monitoring/live/`. A 404 does not imply an image rebuild is needed. |
| `.env` is missing or invalid | `Test-Path .env`; `docker compose config --quiet` | If the file is missing, Compose's required `env_file` cannot be loaded. Invalid or placeholder values can also cause authentication/configuration failures. | Copy `.env.example` only when `.env` is absent; edit the existing file without displaying its values. Replace placeholder secrets with private random values. |
| MQTT service is unavailable | `docker compose ps mqtt listener` and `docker compose logs --tail 100 mqtt listener` | MQTT listens on host port 1883 and WebSockets on 9001; the listener connects to the Compose service name `mqtt` on port 1883. | Check the broker/listener logs and `docker/mosquitto.conf`; restart just the affected service after addressing the cause. |
| A frontend dependency changed | `git diff -- app/web/package.json app/web/package-lock.json` | Compose mounts a persistent `web-node-modules` volume and runs `npm ci` at web-container start. | Review and save the lockfile, then run `docker compose restart web`. The web image is not built by this Compose service. |
| A change works locally but is absent on GitHub | `git status --short; git branch --show-current; git log -1 --oneline; git status -sb` | The change may be uncommitted, unstaged, on another branch, or not pushed. | Review and stage only intended files, commit on `feature/ui-overhaul`, then run `git push origin feature/ui-overhaul`. |
| AI endpoint responds but image analysis does not | `docker compose ps ai; docker compose logs --tail 100 ai` | `/health` tests FastAPI process health, not availability of host-side Ollama. Compose points Ollama at `host.docker.internal:11434`. | If image analysis is needed, check the local Ollama service/model and AI logs. Do not rebuild Django for an unavailable host-side model. |

## 7. Ready-to-copy command blocks

### A. First-time setup

For a fresh clone:

```powershell
Set-Location "$HOME\Downloads"
git clone --branch feature/ui-overhaul --single-branch https://github.com/moetez-dev/Dialyse.git Dialyse
Set-Location "$HOME\Downloads\Dialyse"
git rev-parse --show-toplevel
git remote -v
git branch --show-current
git status --short
if (-not (Test-Path -LiteralPath ".env")) { Copy-Item ".env.example" ".env" }
notepad .env
docker version
docker compose version
docker compose config --quiet
docker compose up -d --build --wait
docker compose ps --all
```

Set private values in `.env` before the Compose command. Do not run the
`Copy-Item` line if you already have a different checkout or `.env`; use the
guarded copy procedure above.

### B. Daily startup

```powershell
Set-Location "C:\Users\moetez\Downloads\Dialyse-ui-overhaul"
git branch --show-current
git status --short
docker compose up -d --wait
```

### C. Check service status

```powershell
docker compose ps --all
docker compose config --services
```

### D. View logs

```powershell
docker compose logs --tail 100
docker compose logs --tail 200 web
docker compose logs --tail 200 api
docker compose logs --tail 200 ai
docker compose logs --tail 200 mqtt listener
docker compose logs -f web
```

Press `Ctrl+C` to stop following logs; it does not stop the containers.

### E. Restart the frontend only

```powershell
docker compose restart web
docker compose logs --tail 100 web
```

### F. Rebuild when justified

First setup or a Python Dockerfile/requirements change:

```powershell
docker compose up -d --build --wait
```

Rebuild/update only the shared Python services:

```powershell
docker compose up -d --build --wait api ai listener
```

For changed web dependencies, restart the web container so its configured
startup command runs `npm ci`; a Python image rebuild is not needed:

```powershell
docker compose restart web
```

### G. Stop services safely

```powershell
docker compose stop
```

This keeps the containers and volumes for the next session. Do not append
`-v` to `docker compose down`.

### H. Check Git branch and changes

```powershell
git rev-parse --show-toplevel
git branch --show-current
git branch -vv
git status --short
git diff --stat
git fetch origin
git status -sb
git log --oneline --left-right feature/ui-overhaul...origin/feature/ui-overhaul
git diff --stat feature/ui-overhaul origin/feature/ui-overhaul
```

### I. Commit and push to `feature/ui-overhaul`

Replace the sample path with the specific files you intended to change:

```powershell
if ((git branch --show-current) -ne "feature/ui-overhaul") {
    throw "Not on feature/ui-overhaul; do not commit or push."
}
git status --short
git diff --check
git add -- path\to\intended-file
git diff --cached --stat
git diff --cached
git commit -m "Describe your change"
git status -sb
git push origin feature/ui-overhaul
```

## Optional PowerShell helper

A small `start-dialyse.ps1` could check the repository root, confirm the
current branch is `feature/ui-overhaul`, verify `.env` without printing it,
check Docker availability, run `docker compose up -d --wait`, and print
`docker compose ps --all`. It should refuse to switch branches or remove
containers/volumes. No helper script is created by this runbook; the commands
above remain directly usable and auditable.
