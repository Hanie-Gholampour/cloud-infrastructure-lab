#!/bin/sh
set -eu # fail on error

# TODO[VCC-010]: Create entrypoint for grafana. It should support replicated deployments

# Wait until database is alive. Grafana image comes with netcat (nc)

# Configuration
DB_HOST="${GF_DATABASE_HOST:-db}"
DB_PORT="${GF_DATABASE_PORT:-5432}"

# Wait until database is alive
echo "Waiting for database at $DB_HOST:$DB_PORT..."
while ! nc -z -w 1 "$DB_HOST" "$DB_PORT" 2>/dev/null; do
    echo "Database not ready, waiting..."
    sleep 2
done
echo "Database is ready!"

# Execute the original Grafana entrypoint
exec /run.sh "$@"