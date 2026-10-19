#!/bin/sh
# Shared entrypoint for every Python service in the stack.
# Only the web service owns the schema; the others just wait for it.
set -e

if [ "$RUN_MIGRATIONS" = "1" ]; then
    echo "[entrypoint] applying migrations"
    cd /workspace/app/api/django
    python manage.py migrate --noinput
fi

if [ -n "$WAIT_FOR_DB" ]; then
    service_dir="$(pwd)"
    cd /workspace/app/api/django
    # Companion services must not start against a half-built database.
    until python -c "import django, os; os.environ.setdefault('DJANGO_SETTINGS_MODULE','PFA.settings'); django.setup(); from django.db import connection; connection.introspection.table_names()" 2>/dev/null; do
        echo "[entrypoint] waiting for database..."
        sleep 2
    done
    cd "$service_dir"
fi

exec "$@"
