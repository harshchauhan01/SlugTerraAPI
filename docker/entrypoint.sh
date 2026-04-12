#!/bin/sh
set -e

echo "Waiting for PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}..."

while ! (getent hosts "$POSTGRES_HOST" >/dev/null 2>&1 && nc -z "$POSTGRES_HOST" "$POSTGRES_PORT"); do
  echo "PostgreSQL host not ready yet, retrying..."
  sleep 1
done

echo "PostgreSQL is up"

python manage.py migrate --noinput

exec "$@"