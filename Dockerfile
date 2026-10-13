# ---- Stage 1: compile the Tailwind stylesheet -------------------------------
FROM node:24-alpine AS css

WORKDIR /build

COPY package.json package-lock.json ./
RUN npm ci

# Only what the Tailwind scanner reads (see @source rules in app.css).
COPY static/css/src ./static/css/src
COPY static/js ./static/js
COPY templates ./templates
COPY accounts/templates ./accounts/templates
COPY monitoring/templates ./monitoring/templates
COPY patients/templates ./patients/templates
COPY seances/templates ./seances/templates
COPY machines/templates ./machines/templates
COPY core ./core

RUN npm run css:build


# ---- Stage 2: the Django application ----------------------------------------
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt requirements-services.txt ./

RUN pip install --no-cache-dir -r requirements.txt -r requirements-services.txt

COPY . .

# The compiled stylesheet, so the image works without ever running npm.
COPY --from=css /build/static/css/index.css ./static/css/index.css

RUN chmod +x docker/entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["docker/entrypoint.sh"]
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
