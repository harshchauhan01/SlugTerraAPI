FROM python:3.12-slim AS base

# This Dockerfile expects the build context to be the config directory.
# Example: docker build -f docker/Dockerfile -t <image>:<tag> .

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

FROM base AS dev-deps

COPY requirements/base.txt /app/requirements/base.txt
COPY requirements/dev.txt /app/requirements/dev.txt

RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements/dev.txt

FROM base AS prod-builder

COPY requirements/base.txt /app/requirements/base.txt
COPY requirements/prod.txt /app/requirements/prod.txt

RUN pip install --upgrade pip && \
    pip wheel --no-cache-dir --no-deps -r /app/requirements/prod.txt -w /wheels

FROM dev-deps AS development

COPY manage.py /app/manage.py
COPY config /app/config
COPY slugs /app/slugs
COPY slugs_data.json /app/slugs_data.json
COPY docker /app/docker

RUN chmod +x /app/docker/entrypoint.sh

ENTRYPOINT ["/app/docker/entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]

FROM base AS production

COPY --from=prod-builder /wheels /wheels
RUN pip install /wheels/*

COPY manage.py /app/manage.py
COPY config /app/config
COPY slugs /app/slugs
COPY slugs_data.json /app/slugs_data.json
COPY docker /app/docker

RUN chmod +x /app/docker/entrypoint.sh

ENTRYPOINT ["/app/docker/entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000"]