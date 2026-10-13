# Compile styles for Django pages that have not yet moved to Next.js.
FROM node:24-alpine AS css

WORKDIR /workspace
COPY package.json package-lock.json ./
RUN npm ci

COPY app/web/public/static/css/src ./app/web/public/static/css/src
COPY app/web/public/static/js ./app/web/public/static/js
COPY app/api/django/templates ./app/api/django/templates
COPY app/api/django/accounts/templates ./app/api/django/accounts/templates
COPY app/api/django/monitoring/templates ./app/api/django/monitoring/templates
COPY app/api/django/patients/templates ./app/api/django/patients/templates
COPY app/api/django/seances/templates ./app/api/django/seances/templates
COPY app/api/django/machines/templates ./app/api/django/machines/templates
COPY app/api/django/core ./app/api/django/core
RUN npm run css:build

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /workspace

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY app/api/requirements.txt app/api/requirements-services.txt /workspace/app/api/
RUN pip install --no-cache-dir \
    -r /workspace/app/api/requirements.txt \
    -r /workspace/app/api/requirements-services.txt

COPY . /workspace
COPY --from=css /workspace/app/web/public/static/css/index.css /workspace/app/web/public/static/css/index.css

RUN chmod +x /workspace/docker/entrypoint.sh

WORKDIR /workspace/app/api/django
EXPOSE 8000 8001

ENTRYPOINT ["/workspace/docker/entrypoint.sh"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
