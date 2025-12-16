#!/bin/sh
set -eu # fail on error

CONFIG="/config/configuration.yml"
SECRET_FILE="/run/secrets/jwks_key"

# TODO[VCC-006]: Create entrypoint for authelia. It should support replicated deployments

# wait until database is alive
# Authelia image comes with netcat (nc) installed and apt is not available

# Check if Authelia has been configured before

# Inject jwks key from secrets
echo "Injecting jwks key from secrets"
# keep space indentation for yaml (ugh!)
JWKS_KEY=$(sed 's/^/          /' "$SECRET_FILE")
sed -i '/JWKS_PRIVATE_KEY_CONTENT/{
    r /dev/stdin
    d
}' "$CONFIG" <<EOF
$JWKS_KEY
EOF

echo "Initialize Authelia database schema"
authelia storage migrate up -c "$CONFIG"
# Mark Authelia as configured

# Execute the original entrypoint