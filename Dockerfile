FROM python:3.12-slim as base

ENV PYTHONDONTWRITEBYTECODE=1\
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

FROM base as builder

COPY requirements/base.txt requirements/prod.txt ./

RUN pip install --upgrade pip && \
pip wheel --no-cache-dir --no-deps -r prod.txt -w /wheels


FROM base as production

RUN adduser --disabled-password --no-create-home django
COPY --from=builder /wheels /wheels
RUN pip install /wheels/*

COPY . .
USER django

CMD ["gunicorn","config.wsgi:application", "--bind","0.0.0.0:8000"]

FROM base as development

COPY requirements/base.txt requirements/dev.txt ./

RUN pip install --upgrade pip && \
    pip install -r dev.txt

COPY . .

CMD ["python","manage.py", "runserver","0.0.0.0:8000"]