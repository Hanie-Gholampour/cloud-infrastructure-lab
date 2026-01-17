#!/bin/sh
set -eu # fail on error

# Make forgejo trust our TLS certificate
update-ca-certificates 2>/dev/null || true

# TODO[VCC-008]: Create entrypoint for forgejo. It should support replicated deployments
# Configuration
LOCK_FILE="/data/gitea/.forgejo_configured"
DB_HOST="${FORGEJO_DB_HOST:-postgres}"
DB_PORT="${FORGEJO_DB_PORT:-5432}"
DB_NAME="${FORGEJO_DB_NAME:-forgejo}"
DB_USER="${FORGEJO_DB_USER:-forgejo}"
DB_PASS="${FORGEJO_DB_PASS:-forgejo}"
ADMIN_USER="${FORGEJO_ADMIN_USER:-admin}"
ADMIN_PASS="${FORGEJO_ADMIN_PASS:-admin}"
ADMIN_EMAIL="${FORGEJO_ADMIN_EMAIL:-admin@vcc.local}"
AUTH_URL="${FORGEJO_AUTH_URL:-https://auth.vcc.local}"
DOMAIN_NAME="${DOMAIN_NAME:-vcc.local}"


# This helper allows to run stuff as the forgejo user
# Looks like it's missing the `sudo` executable
forgejo_cli() { su -c "forgejo --config /data/gitea/conf/app.ini $*" git; }




# Wait until database is alive
#  - port alive                         (bad)
#  - a mock query like 'SELECT 1' works (better)

# Wait until database is alive using a mock query
echo "Waiting for database at $DB_HOST:$DB_PORT (database: $DB_NAME, user: $DB_USER)..."


# First, wait for TCP connectivity (network layer)
echo "Checking TCP connectivity to $DB_HOST:$DB_PORT..."
MAX_TCP_RETRIES=30
TCP_RETRY_COUNT=0
while ! nc -zw5 "$DB_HOST" "$DB_PORT" 2>/dev/null; do
    TCP_RETRY_COUNT=$((TCP_RETRY_COUNT + 1))
    if [ $TCP_RETRY_COUNT -ge $MAX_TCP_RETRIES ]; then
        echo "ERROR: Cannot establish TCP connection to $DB_HOST:$DB_PORT after $MAX_TCP_RETRIES attempts"
        echo "Attempting to resolve hostname: $DB_HOST"
        getent hosts "$DB_HOST" || echo "Cannot resolve $DB_HOST"
        echo "Network may not be ready. Continuing to retry..."
    fi
    echo "TCP connection not ready (attempt $TCP_RETRY_COUNT), waiting..."
    sleep 2
done
echo "TCP connectivity established!"

# Now wait for PostgreSQL to be ready and accepting queries
echo "Waiting for PostgreSQL to accept connections..."
MAX_RETRIES=60
RETRY_COUNT=0
while ! PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" >/dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "WARNING: Database not accepting queries after $MAX_RETRIES attempts"
        echo "Last psql error:"
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" 2>&1 || true
        echo "Continuing to retry..."
    fi
    # Show actual error every 10 attempts for debugging
    if [ $((RETRY_COUNT % 10)) -eq 0 ]; then
        echo "Database not ready (attempt $RETRY_COUNT/$MAX_RETRIES), last error:"
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" 2>&1 || true
    else
        echo "Database not ready (attempt $RETRY_COUNT/$MAX_RETRIES), waiting..."
    fi
    sleep 3
done
echo "Database is ready!"

# Check if it's the first run (see if lock file exists)
if [ -f "$LOCK_FILE" ]; then
    echo "Forgejo already configured, skipping initialization..."
    exec /usr/bin/entrypoint "$@"
fi


# Check if it's the first run (see if /data/gitea/conf/app.ini exists)
echo "First run detected"
mkdir -p /data/gitea
mkdir -p /data/queues
mkdir -p /data/gitea/conf
cp /conf/app.ini /data/gitea/conf/app.ini
# Fix permission for data directory
chown -R git:git /data/gitea
chown -R git:git /data/queues

# DB migration
echo "Initialize forgejo database"
forgejo_cli migrate

# Create admin user (if it does not exists already)
# use `forgejo_cli admin user list` and `forgejo_cli admin user create`
echo "Checking admin user..."
if ! forgejo_cli admin user list | grep -q "$ADMIN_USER"; then
    echo "Creating admin user: $ADMIN_USER"
    forgejo_cli admin user create \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASS" \
        --email "$ADMIN_EMAIL" \
        --admin
else
    echo "Admin user already exists"
fi


# Wait until authentication server is alive
#  - port alive                         (bad)
#  - check that the web server responds (better)
#    Authelia exposes /api/health to check status
#    For example: curl -kfsS https://auth.vcc.local/api/health returns {"status":"OK"}
AUTHELIA_INTERNAL_URL="http://authelia:9091"
echo "Waiting for authentication server (internal: $AUTHELIA_INTERNAL_URL)..."
while ! curl -fsS "$AUTHELIA_INTERNAL_URL/api/health" 2>/dev/null | grep -q '"status":"OK"'; do
    echo "Auth server not ready, waiting..."
    sleep 2
done
echo "Auth server is ready!"




# Setup authentication (if it does not exist)
# use `forgejo_cli admin auth list` and `forgejo_cli admin auth add-oauth`
#   --auto-discover-url is `https://auth.{{domain_name}}/.well-known/openid-configuration`
#   --provider is openidConnect

echo "Checking OAuth authentication..."
if ! forgejo_cli admin auth list | grep -q "authelia"; then
    echo "Setting up OAuth authentication with Authelia"
    forgejo_cli admin auth add-oauth \
        --name "authelia" \
        --provider "openidConnect" \
        --auto-discover-url "https://auth.${DOMAIN_NAME}/.well-known/openid-configuration" \
        --key "forgejo" \
        --secret "${FORGEJO_OAUTH_SECRET:-forgejo-secret}"
else
    echo "OAuth authentication already configured"
fi

# Mark Forgejo as configured
touch "$LOCK_FILE"
echo "Forgejo initialization complete"

# Execute the original entrypoint
exec /usr/bin/entrypoint "$@"