#!/bin/sh
set -eu # fail on error

CONFIG_SRC="/config/configuration.yml"
CONFIG="/tmp/configuration.yml"
SECRET_FILE="/run/secrets/jwks_key"

# TODO[VCC-006]: Create entrypoint for authelia. It should support replicated deployments

# Authelia database connection settings
DB_HOST="postgres"
DB_PORT="5432"
DB_NAME="${AUTHELIA_STORAGE_POSTGRES_DATABASE:-autheliadb}"
DB_USER="${AUTHELIA_STORAGE_POSTGRES_USERNAME:-authelia}"
DB_PASS="${AUTHELIA_STORAGE_POSTGRES_PASSWORD:-}"

echo "Authelia database config: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"



# wait until database is alive
# Authelia image comes with netcat (nc) installed and apt is not available
# Check if Authelia has been configured before
echo "Waiting for database at $DB_HOST:$DB_PORT..."
MAX_RETRIES=60
RETRY=0
while ! nc -w 1 "$DB_HOST" "$DB_PORT" </dev/null 2>/dev/null; do
    RETRY=$((RETRY + 1))
    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
        echo "Database connection timeout after $MAX_RETRIES attempts"
        exit 1
    fi
    echo "Database not ready, waiting... (attempt $RETRY/$MAX_RETRIES)"
    sleep 2
done
echo "Database port is open!"


# Additional wait for PostgreSQL to fully initialize
echo "Waiting additional 5s for PostgreSQL to be fully ready..."
sleep 5

# Copy config to writable location
cp "$CONFIG_SRC" "$CONFIG"

# Inject jwks key from secrets
echo "Injecting jwks key from secrets"
# Use awk to properly handle multiline key replacement with correct indentation
awk -v keyfile="$SECRET_FILE" '
/JWKS_PRIVATE_KEY_CONTENT/ {
    while ((getline line < keyfile) > 0) {
        print "          " line
    }
    next
}
{print}
' "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"






# Check if Authelia database schema needs migration
# Add random delay (0-15 seconds) to reduce race conditions between replicas
DELAY=$(($(od -An -N1 -tu1 /dev/urandom) % 16))
echo "Waiting ${DELAY}s before checking migration status (anti-collision delay)..."
sleep "$DELAY"

echo "Checking database schema..."
MIGRATE_STATUS=$(authelia storage migrate status -c "$CONFIG" 2>&1 || true)

if echo "$MIGRATE_STATUS" | grep -qi "up-to-date"; then
    echo "Database schema already up-to-date, skipping migration..."
elif echo "$MIGRATE_STATUS" | grep -qi "Storage schema is on version"; then
    echo "Database schema exists, skipping migration..."
else
    echo "Initialize Authelia database schema"
    # Try migration, capture output to check for "already up to date" message
    MIGRATE_OUTPUT=$(authelia storage migrate up -c "$CONFIG" 2>&1) || MIGRATE_EXIT=$?
    MIGRATE_EXIT=${MIGRATE_EXIT:-0}
    
    if [ "$MIGRATE_EXIT" -eq 0 ]; then
        echo "Migration completed successfully"
    elif echo "$MIGRATE_OUTPUT" | grep -qi "already up to date"; then
        # "schema already up to date" is not an error - another replica did it
        echo "Schema already up to date (migrated by another replica), continuing..."
    elif echo "$MIGRATE_OUTPUT" | grep -qi "rollback\|duplicate key"; then
        # Migration rollback or duplicate key means another replica is migrating
        echo "Migration conflict detected (another replica is migrating), waiting..."
        sleep 10
        # Check if schema now exists after waiting
        if authelia storage migrate status -c "$CONFIG" 2>&1 | grep -qiE "up-to-date|version"; then
            echo "Schema now exists (migrated by another replica), continuing..."
        else
            echo "Migration conflict but schema still not ready, retrying once..."
            authelia storage migrate up -c "$CONFIG" 2>&1 || true
        fi
    else
        echo "Migration returned exit code $MIGRATE_EXIT, checking if schema now exists..."
        echo "Migration output: $MIGRATE_OUTPUT"
        sleep 5
        if authelia storage migrate status -c "$CONFIG" 2>&1 | grep -qiE "up-to-date|version"; then
            echo "Schema exists (likely migrated by another replica), continuing..."
        else
            echo "Migration truly failed!"
            exit 1
        fi
    fi
fi





echo "Authelia initialization complete"

# Execute the original entrypoint
exec authelia --config "$CONFIG" "$@"