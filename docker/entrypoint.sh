#!/bin/sh
set -e

echo "Waiting for PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}..."

WAIT_HOSTS="${POSTGRES_HOST:-db} db postgres_db"
MAX_WAIT_SECONDS="${POSTGRES_WAIT_TIMEOUT_SECONDS:-60}"
elapsed=0

while :; do
  for host in $WAIT_HOSTS; do
    if nc -z "$host" "$POSTGRES_PORT" >/dev/null 2>&1; then
      POSTGRES_HOST="$host"
      break 2
    fi
  done

  if [ "$elapsed" -ge "$MAX_WAIT_SECONDS" ]; then
    echo "Timed out waiting for PostgreSQL after ${MAX_WAIT_SECONDS}s" >&2
    exit 1
  fi

  echo "PostgreSQL host not ready yet, retrying..."
  sleep 1
  elapsed=$((elapsed + 1))
done

echo "PostgreSQL is up"

python manage.py migrate --noinput

exec "$@"